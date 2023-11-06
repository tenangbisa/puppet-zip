# frozen_string_literal: true

require_relative '../../../puppet_x/bodeco/zip'
require_relative '../../../puppet_x/bodeco/util'

require 'securerandom'
require 'tempfile'

# This provider implements a simple state-machine. The following attempts to #
# document it. In general, `def adjective?` implements a [state], while `def
# verb` implements an {action}.
# Some states are more complex, as they might depend on other states, or trigger
# actions. Since this implements an ad-hoc state-machine, many actions or states
# have to guard themselves against being called out of order.
#
# [exists?]
#   |
#   v
# [extracted?] -> no -> [checksum?]
#    |
#    v
#   yes
#    |
#    v
# [path.exists?] -> no -> {cleanup}
#    |                    |    |
#    v                    v    v
# [checksum?]            yes. [extracted?] && [cleanup?]
#                              |
#                              v
#                            {destroy}
#
# Now, with [exists?] defined, we can define [ensure]
# But that's just part of the standard puppet provider state-machine:
#
# [ensure] -> absent -> [exists?] -> no.
#   |                     |
#   v                     v
#  present               yes
#   |                     |
#   v                     v
# [exists?]            {destroy}
#   |
#   v
# {create}
#
# Here's how we would extend zip for an `ensure => latest`:
#
#  [exists?] -> no -> {create}
#    |
#    v
#   yes
#    |
#    v
#  [ttl?] -> expired -> {destroy} -> {create}
#    |
#    v
#  valid.
#

Puppet::Type.type(:zip).provide(:ruby) do
  optional_commands aws: 'aws'
  optional_commands gsutil: 'gsutil'
  defaultfor feature: :microsoft_windows
  attr_reader :zip_checksum

  def exists?
    return checksum? unless extracted?
    return checksum? if File.exist? zip_filepath

    cleanup
    true
  end

  def create
    transfer_download(zip_filepath) unless checksum?
    extract
  ensure
    cleanup
  end

  def destroy
    FileUtils.rm_f(zip_filepath) if File.exist?(zip_filepath)
  end

  def zip_filepath
    resource[:path]
  end

  def tempfile_name
    if resource[:checksum] == 'none'
      "#{resource[:filename]}_#{SecureRandom.base64}"
    else
      "#{resource[:filename]}_#{resource[:checksum]}"
    end
  end

  def creates
    if resource[:extract] == :true
      extracted? ? resource[:creates] : 'zip not extracted'
    else
      resource[:creates]
    end
  end

  def creates=(_value)
    extract
  end

  def checksum
    resource[:checksum] || (resource[:checksum] = remote_checksum if resource[:checksum_url])
  end

  def remote_checksum
    PuppetX::Bodeco::Util.content(
      resource[:checksum_url],
      username: resource[:username],
      password: resource[:password],
      cookie: resource[:cookie],
      proxy_server: resource[:proxy_server],
      proxy_type: resource[:proxy_type],
      insecure: resource[:allow_insecure]
    )[%r{\b[\da-f]{32,128}\b}i]
  end

  # Private: See if local zip checksum matches.
  # returns boolean
  def checksum?(store_checksum = true)
    return false unless File.exist? zip_filepath
    return true  if resource[:checksum_type] == :none

    zip = PuppetX::Bodeco::zip.new(zip_filepath)
    zip_checksum = zip.checksum(resource[:checksum_type])
    @zip_checksum = zip_checksum if store_checksum
    checksum == zip_checksum
  end

  def cleanup
    return unless resource[:cleanup] == :true && resource[:extract] == :true

    Puppet.debug("Cleanup zip #{zip_filepath}")
    destroy
  end

  def extract
    return unless resource[:extract] == :true
    raise(ArgumentError, 'missing zip extract_path') unless resource[:extract_path]

    PuppetX::Bodeco::zip.new(zip_filepath).extract(
      resource[:extract_path],
      custom_command: resource[:extract_command],
      options: resource[:extract_flags],
      uid: resource[:user],
      gid: resource[:group]
    )
  end

  def extracted?
    resource[:creates] && File.exist?(resource[:creates])
  end

  def transfer_download(zip_filepath)
    raise Puppet::Error, "Temporary directory #{resource[:temp_dir]} doesn't exist" if resource[:temp_dir] && !File.directory?(resource[:temp_dir])

    tempfile = Tempfile.new(tempfile_name, resource[:temp_dir])

    temppath = tempfile.path
    tempfile.close!

    case resource[:source]
    when %r{^(puppet)}
      puppet_download(temppath)
    when %r{^(http|ftp)}
      download(temppath)
    when %r{^file}
      uri = URI(resource[:source])
      FileUtils.copy(Puppet::Util.uri_to_path(uri), temppath)
    when %r{^s3}
      s3_download(temppath)
    when %r{^gs}
      gs_download(temppath)
    when nil
      raise(Puppet::Error, 'Unable to fetch zip, the source parameter is nil.')
    else
      raise(Puppet::Error, "Source file: #{resource[:source]} does not exists.") unless File.exist?(resource[:source])

      FileUtils.copy(resource[:source], temppath)
    end

    # conditionally verify checksum:
    if resource[:checksum_verify] == :true && resource[:checksum_type] != :none
      zip = PuppetX::Bodeco::zip.new(temppath)
      actual_checksum = zip.checksum(resource[:checksum_type])
      if actual_checksum != checksum
        destroy
        raise(Puppet::Error, "Download file checksum mismatch (expected: #{checksum} actual: #{actual_checksum})")
      end
    end

    move_file_in_place(temppath, zip_filepath)
  ensure
    FileUtils.rm_f(temppath) if File.exist?(temppath)
  end

  def move_file_in_place(from, to)
    # Ensure to directory exists.
    FileUtils.mkdir_p(File.dirname(to))
    FileUtils.mv(from, to)
  end

  def download(filepath)
    PuppetX::Bodeco::Util.download(
      resource[:source],
      filepath,
      username: resource[:username],
      password: resource[:password],
      cookie: resource[:cookie],
      proxy_server: resource[:proxy_server],
      proxy_type: resource[:proxy_type],
      insecure: resource[:allow_insecure]
    )
  end

  def puppet_download(filepath)
    PuppetX::Bodeco::Util.puppet_download(
      resource[:source],
      filepath
    )
  end

  def s3_download(path)
    params = [
      's3',
      'cp',
      resource[:source],
      path
    ]
    params += resource[:download_options] if resource[:download_options]

    aws(params)
  end

  def gs_download(path)
    params = [
      'cp',
      resource[:source],
      path
    ]
    params += resource[:download_options] if resource[:download_options]

    gsutil(params)
  end

  def optional_switch(value, option)
    if value
      Array(value).map { |item| option.map { |flags| flags % item } }.flatten
    else
      []
    end
  end
end
