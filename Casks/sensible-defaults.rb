# Lives in the tap repo (rupert-br/homebrew-tap) once a notarized release exists.
cask "sensible-defaults" do
  version "0.1.0"
  sha256 "a211f1f73d307fb9470565b48df0ae8e990d14f211950cd244ef803ffb3a5be1"

  url "https://github.com/rupert-br/sensible-defaults/releases/download/v#{version}/SensibleDefaults-#{version}.zip"
  name "Sensible Defaults"
  desc "Open developer files with a menu of your editors instead of Xcode"
  homepage "https://github.com/rupert-br/sensible-defaults"

  depends_on macos: ">= :ventura"

  app "Sensible Defaults.app"

  # Launch Services only honours the file type claims of an app that has been launched once.
  postflight do
    system_command "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                   args: ["-f", "#{appdir}/Sensible Defaults.app"]
    system_command "/usr/bin/open",
                   args: ["-g", "#{appdir}/Sensible Defaults.app", "--args", "--register"]
  end

  uninstall quit: "io.github.rupert-br.sensible-defaults"

  zap trash: "~/Library/Preferences/io.github.rupert-br.sensible-defaults.plist"
end
