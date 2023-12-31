# frozen_string_literal: true

Facter.add(:zip_windir) do
  confine :osfamily => :windows # rubocop:disable Style/HashSyntax
  setcode do
    program_data = `echo %SYSTEMDRIVE%\\ProgramData`.chomp
    if File.directory? program_data
      "#{program_data}\\staging"
    else
      'C:\\staging'
    end
  end
end
