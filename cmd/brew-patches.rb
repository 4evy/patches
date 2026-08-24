#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'
require 'fileutils'
require 'tmpdir'
require 'uri'

ROOT = File.expand_path('..', __dir__)
STACKS = ENV.fetch('PATCHES_STACKS', File.join(ROOT, 'stacks'))
SCHEMA = 'https://raw.githubusercontent.com/4evy/patches/master/schema/stack-v1.schema.json'
REVISION = /\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/i
ID = /\A[a-z0-9][a-z0-9._-]*\z/

def usage
  puts <<~TEXT
    Usage:
      brew-patches list [--json]
      brew-patches show STACK [--json]
      brew-patches validate [STACK]
      brew-patches check STACK SOURCE_DIR
      brew-patches apply STACK SOURCE_DIR

    Browse, validate, check, or apply an ordered Git patch stack.
    `check` never changes SOURCE_DIR; `apply` changes it only after the
    complete queue passes a dry-run check.

    When installed as a Homebrew external command, use `brew patches`
    in place of `brew-patches`.
  TEXT
end

def stack_names
  return [] unless Dir.exist?(STACKS)

  Dir.children(STACKS).select do |name|
    path = File.join(STACKS, name)
    File.directory?(path) && !File.symlink?(path) && name.match?(ID)
  end.sort
end

def stack_path(id)
  abort "Unknown stack: #{id}" unless stack_names.include?(id)
  File.join(STACKS, id)
end

def manifest_for(id)
  directory = File.realpath(stack_path(id))
  path = File.realpath(File.join(directory, 'stack.json'))
  unless path.start_with?("#{directory}#{File::SEPARATOR}") && File.file?(path)
    abort "Manifest escapes the stack directory for #{id}"
  end

  JSON.parse(File.read(path))
rescue Errno::ENOENT
  abort "Missing manifest for #{id}"
rescue JSON::ParserError => e
  abort "Invalid manifest for #{id}: #{e.message}"
end

def series_for(id)
  base = patch_directory(id)
  path = File.realpath(File.join(base, 'series'))
  unless path.start_with?("#{base}#{File::SEPARATOR}") && File.file?(path)
    raise "series file escapes patches/ for #{id}"
  end

  File.readlines(path, chomp: true).filter_map do |line|
    entry = line.sub(/\s+#.*\z/, '').strip
    next if entry.empty? || entry.start_with?('#')

    entry
  end
rescue Errno::ENOENT
  abort "Missing series file for #{id}"
end

def patch_directory(id)
  directory = File.realpath(stack_path(id))
  base = File.realpath(File.join(directory, 'patches'))
  unless base.start_with?("#{directory}#{File::SEPARATOR}") &&
         File.directory?(base)
    raise "patches/ escapes the stack directory for #{id}"
  end

  base
end

def patch_paths(id)
  base = patch_directory(id)
  series_for(id).map do |name|
    path = File.expand_path(name, base)
    resolved_path = File.realpath(path) if File.file?(path)
    unless name.end_with?('.patch') &&
           path.start_with?("#{base}#{File::SEPARATOR}") &&
           resolved_path&.start_with?("#{base}#{File::SEPARATOR}")
      raise "series entry does not name a patch below patches/: #{name}"
    end

    [name, path]
  end
end

def reject_extra_keys(value, allowed, context, errors)
  (value.keys - allowed).sort.each do |key|
    errors << "#{context} contains unknown property #{key}"
  end
end

def valid_uri?(value)
  value.is_a?(String) && URI.parse(value).absolute?
rescue URI::InvalidURIError
  false
end

def validate_manifest(id)
  manifest = manifest_for(id)
  errors = []
  unless manifest.is_a?(Hash)
    return ['manifest must be an object']
  end

  reject_extra_keys(manifest, %w[$schema manifestVersion id source result],
                    'manifest', errors)
  unless manifest['$schema'] == SCHEMA
    errors << '$schema does not identify stack-v1.schema.json'
  end
  unless manifest['manifestVersion'] == 1
    errors << 'manifestVersion must be 1'
  end
  unless manifest['id'] == id
    errors << 'id does not match the directory name'
  end
  source = manifest['source']
  if source.is_a?(Hash)
    reject_extra_keys(
      source,
      %w[vcs canonical revision trackingRef endpoints checkout],
      'source', errors
    )
    errors << 'source.vcs must be git' unless source['vcs'] == 'git'
    unless source['revision'].is_a?(String) &&
           source['revision'].match?(REVISION)
      errors << 'source.revision must be a full Git object ID'
    end
    unless valid_uri?(source['canonical'])
      errors << 'source.canonical must be a URI'
    end
    if source.key?('trackingRef') &&
       !(source['trackingRef'].is_a?(String) &&
         source['trackingRef'].start_with?('refs/'))
      errors << 'source.trackingRef must start with refs/'
    end

    endpoints = source['endpoints']
    if endpoints.is_a?(Array) && !endpoints.empty?
      endpoints.each_with_index do |endpoint, index|
        context = "source.endpoints[#{index}]"
        unless endpoint.is_a?(Hash)
          errors << "#{context} must be an object"
          next
        end

        reject_extra_keys(endpoint, %w[url role priority], context, errors)
        unless valid_uri?(endpoint['url'])
          errors << "#{context}.url must be a URI"
        end
        unless %w[primary mirror].include?(endpoint['role'])
          errors << "#{context}.role is invalid"
        end
        unless endpoint['priority'].is_a?(Integer) &&
               endpoint['priority'] >= 0
          errors << "#{context}.priority must be a non-negative integer"
        end
      end
    else
      errors << 'source.endpoints must be a non-empty array'
    end

    if source.key?('checkout')
      checkout = source['checkout']
      if checkout.is_a?(Hash)
        reject_extra_keys(
          checkout, %w[submodules lfs], 'source.checkout', errors
        )
        if checkout.key?('submodules') &&
           ![false, 'recursive'].include?(checkout['submodules'])
          errors << 'source.checkout.submodules must be false or recursive'
        end
        if checkout.key?('lfs') && ![true, false].include?(checkout['lfs'])
          errors << 'source.checkout.lfs must be a boolean'
        end
      else
        errors << 'source.checkout must be an object'
      end
    end
  else
    errors << 'source must be an object'
  end

  if manifest.key?('result')
    result = manifest['result']
    if result.is_a?(Hash)
      reject_extra_keys(result, %w[tree], 'result', errors)
      tree = result['tree']
      if tree.is_a?(Hash)
        reject_extra_keys(tree, %w[algorithm oid], 'result.tree', errors)
        unless %w[sha1 sha256].include?(tree['algorithm'])
          errors << 'result.tree.algorithm is invalid'
        end
        unless tree['oid'].is_a?(String) && tree['oid'].match?(REVISION)
          errors << 'result.tree.oid must be a full object ID'
        end
      else
        errors << 'result.tree must be an object'
      end
    else
      errors << 'result must be an object'
    end
  end

  errors
end

def validate_stack(id)
  errors = validate_manifest(id)
  begin
    series_for(id).tally.each do |name, count|
      next unless count > 1

      errors << "series contains duplicate patch: #{name}"
    end
    patch_paths(id).each do |name, path|
      is_git_patch = File.foreach(path).any? do |line|
        line.start_with?('diff --git ')
      end
      errors << "#{name} is not a Git patch" unless is_git_patch
    end
  rescue StandardError => e
    errors << e.message
  end
  errors
end

def run_git(source, args, patch)
  # Open3 receives an argv vector, so user-controlled values never reach a
  # shell.
  stdout, stderr, status = Open3.capture3( # nosemgrep
    'git', '-C', source, 'apply', *args, patch
  )
  return if status.success?

  abort "git apply failed: #{[stdout, stderr].reject(&:empty?).join}"
end

def apply_queue(source, patches, check_only)
  patches.each_with_index do |patch, index|
    run_git(source, ['--check'], patch)
    run_git(source, [], patch)
    if check_only
      puts "Checked patch #{index + 1}/#{patches.length}: #{File.basename(patch)}"
    end
  end
end

def operate(id, source, apply)
  unless Dir.exist?(source)
    abort "Source directory does not exist: #{source}"
  end
  errors = validate_stack(id)
  unless errors.empty?
    abort errors.map { |error|
      "#{id}: #{error}"
    }.join("\n")
  end
  patches = patch_paths(id).map(&:last)
  Dir.mktmpdir('patches-check') do |temporary|
    FileUtils.cp_r(File.join(source, '.'), temporary)
    apply_queue(temporary, patches, true)
  end
  if apply
    apply_queue(source, patches, false)
    puts "Applied #{patches.length} patches from #{id} to #{File.expand_path(source)}"
  else
    puts "All #{patches.length} patches from #{id} apply cleanly to #{File.expand_path(source)}"
  end
end

json = ARGV.delete('--json') if %w[list show].include?(ARGV.first)
if ARGV == ['list']
  puts(json ? JSON.generate(stack_names) : stack_names)
elsif ARGV.length == 2 && ARGV.first == 'show'
  id = ARGV.last
  errors = validate_stack(id)
  unless errors.empty?
    abort errors.map { |error|
      "#{id}: #{error}"
    }.join("\n")
  end
  data = { 'id' => id, 'manifest' => manifest_for(id),
           'series' => series_for(id), 'patches' => patch_paths(id).map(&:first) }
  puts(json ? JSON.pretty_generate(data) : "Stack: #{id}\n\n#{JSON.pretty_generate(data['manifest'])}\n\nPatch queue:\n#{data['series'].join("\n")}\n")
elsif ARGV == ['validate']
  ids = stack_names
  errors = ids.flat_map do |id|
    validate_stack(id).map do |error|
      "#{id}: #{error}"
    end
  end
  abort errors.join("\n") unless errors.empty?
  puts "Validated #{ids.length} stack#{'s' unless ids.length == 1}."
elsif ARGV.length == 2 && ARGV.first == 'validate'
  id = ARGV.last
  errors = validate_stack(id)
  unless errors.empty?
    abort errors.map { |error|
      "#{id}: #{error}"
    }.join("\n")
  end
  puts "Validated #{id}."
elsif ARGV.length == 3 && ARGV.first == 'check'
  operate(ARGV[1], ARGV[2], false)
elsif ARGV.length == 3 && ARGV.first == 'apply'
  operate(ARGV[1], ARGV[2], true)
elsif ARGV.empty? || ARGV == ['--help'] || ARGV == ['-h']
  usage
else
  warn "Unknown arguments: #{ARGV.join(' ')}"
  usage
  exit 1
end
