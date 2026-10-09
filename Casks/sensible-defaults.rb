cask "sensible-defaults" do
  version "0.1.0"
  sha256 "a211f1f73d307fb9470565b48df0ae8e990d14f211950cd244ef803ffb3a5be1"

  url "https://github.com/rupert-br/sensible-defaults/releases/download/v#{version}/SensibleDefaults-#{version}.zip"
  name "Sensible Defaults"
  desc "Open developer files with a menu of your editors instead of Xcode"
  homepage "https://github.com/rupert-br/sensible-defaults"

  depends_on macos: :ventura

  app "Sensible Defaults.app"

  uninstall quit: "io.github.rupert-br.sensible-defaults"

  zap trash: "~/Library/Preferences/io.github.rupert-br.sensible-defaults.plist"

  caveats <<~EOS
    Open Sensible Defaults once to activate it. macOS only honours an app's
    file type claims after its first launch.
  EOS
end
