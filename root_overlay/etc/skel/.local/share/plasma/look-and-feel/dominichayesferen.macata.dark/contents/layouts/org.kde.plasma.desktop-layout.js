var panel = new Panel
var panelScreen = panel.screen
var freeEdges = {"bottom": true, "top": true, "left": true, "right": true}

for (i = 0; i < panelIds.length; ++i) {
    var tmpPanel = panelById(panelIds[i])
    if (tmpPanel.screen == panelScreen) {
        // Ignore the new panel
        if (tmpPanel.id != panel.id) {
            freeEdges[tmpPanel.location] = false;
        }
    }
}

panel.location = "top";
panel.height = 21;

var spacer = panel.addWidget("org.kde.latte.spacer")
spacer.currentConfigGroup = ["General"]
spacer.writeConfig("lengthPixels", "7")
spacer.writeConfig("lengthType", "Pixels")

panel.addWidget("org.kpple.kppleMenu")

var wintitle = panel.addWidget("org.kde.windowtitle")
wintitle.currentConfigGroup = ["General"]
wintitle.writeConfig("actionScrollMinimize", false)
wintitle.writeConfig("capitalFont", false)
wintitle.writeConfig("filterActivityInfo", false)
wintitle.writeConfig("iconFillThickness", false)
wintitle.writeConfig("lengthFirstMargin", "10")
wintitle.writeConfig("lengthLastMargin", "10")
wintitle.writeConfig("placeHolder", "Finder")
wintitle.writeConfig("showIcon", false)
wintitle.writeConfig("showTooltip", false)
panel.addWidget("org.kde.plasma.appmenu")

panel.addWidget("org.kde.plasma.panelspacer")

panel.addWidget("org.kde.plasma.kimpanel")

var spacer1 = panel.addWidget("org.kde.latte.spacer")
spacer1.currentConfigGroup = ["General"]
spacer1.writeConfig("lengthPixels", "2")
spacer1.writeConfig("lengthType", "Pixels")

trayparent = panel.addWidget("org.kde.plasma.systemtray")
systemtrayId = trayparent.readConfig("SystrayContainmentId");
if (systemtrayId) {
    var systray = desktopById(systemtrayId);
    systray.currentConfigGroup = ["General"];
    systray.writeConfig("knownItems", "org.kde.plasma.printmanager,org.kde.plasma.mediacontroller,org.kde.plasma.networkmanagement,org.kde.plasma.devicenotifier,org.kde.plasma.battery,org.kde.plasma.notifications,org.kde.plasma.keyboardindicator,org.kde.plasma.nightcolorcontrol,org.kde.plasma.bluetooth,org.kde.plasma.clipboard,org.kde.plasma.volume,org.kde.plasma.keyboardlayout,org.kde.plasma.manage-inputmethod,org.kde.kscreen".split(","));
    systray.writeConfig("hiddenItems", "org.kde.plasma.clipboard,org.kde.kscreen,org.kde.plasma.mediacontroller,org.kde.plasma.devicenotifier,org.kde.plasma.manage-inputmethod".split(","));
    systray.writeConfig("extraItems", "org.kde.plasma.mediacontroller,org.kde.plasma.clipboard,org.kde.kscreen,org.kde.plasma.devicenotifier,org.kde.plasma.keyboardlayout,org.kde.plasma.manage-inputmethod".split(","));
    systray.writeConfig("iconSpacing", "5");
    systray.writeConfig("scaleIconsToFit", true);
    systray.reloadConfig();
}

var spacer2 = panel.addWidget("org.kde.latte.spacer")
spacer2.currentConfigGroup = ["General"]
spacer2.writeConfig("lengthPixels", "2")
spacer2.writeConfig("lengthType", "Pixels")

panel.addWidget("org.kde.plasma.printmanager")

var spacer3 = panel.addWidget("org.kde.latte.spacer")
spacer3.currentConfigGroup = ["General"]
spacer3.writeConfig("lengthPixels", "2")
spacer3.writeConfig("lengthType", "Pixels")

panel.addWidget("org.kde.plasma.bluetooth")

var spacer4 = panel.addWidget("org.kde.latte.spacer")
spacer4.currentConfigGroup = ["General"]
spacer4.writeConfig("lengthPixels", "2")
spacer4.writeConfig("lengthType", "Pixels")

panel.addWidget("org.kde.plasma.networkmanagement")

var spacer5 = panel.addWidget("org.kde.latte.spacer")
spacer5.currentConfigGroup = ["General"]
spacer5.writeConfig("lengthPixels", "2")
spacer5.writeConfig("lengthType", "Pixels")

panel.addWidget("org.kde.plasma.volume")

var spacer6 = panel.addWidget("org.kde.latte.spacer")
spacer6.currentConfigGroup = ["General"]
spacer6.writeConfig("lengthPixels", "4")
spacer6.writeConfig("lengthType", "Pixels")

var battery = panel.addWidget("org.kde.plasma.inlineBattery")
battery.currentConfigGroup = ["General"]
battery.writeConfig("fontSize", "11")
battery.writeConfig("iconHeight", "10")
battery.writeConfig("iconWidth", "19")
battery.writeConfig("lowBatteryPercent", "25")
battery.writeConfig("padding", "6")
battery.writeConfig("showPercentage", false)

var spacer7 = panel.addWidget("org.kde.latte.spacer")
spacer7.currentConfigGroup = ["General"]
spacer7.writeConfig("lengthPixels", "5")
spacer7.writeConfig("lengthType", "Pixels")

var clock = panel.addWidget("com.marcinorlowski.htmlclock")
clock.currentConfigGroup = ["Appearance"]
clock.writeConfig("useUserLayout", true)
clock.currentConfigGroup = ["Layout"]
clock.writeConfig("layout", '<html><body><center>{DD:u} {d} {MM:u} {h}:{ii}</center></body></html>')

var spacer8 = panel.addWidget("org.kde.latte.spacer")
spacer8.currentConfigGroup = ["General"]
spacer8.writeConfig("lengthPixels", "5")
spacer8.writeConfig("lengthType", "Pixels")

panel.addWidget("org.kde.milou")

var spacer9 = panel.addWidget("org.kde.latte.spacer")
spacer9.currentConfigGroup = ["General"]
spacer9.writeConfig("lengthPixels", "5")
spacer9.writeConfig("lengthType", "Pixels")

var offbrandsiri = panel.addWidget("org.kde.plasma.folder")
offbrandsiri.currentConfigGroup = ["General"]
offbrandsiri.writeConfig("useCustomIcon", true)
offbrandsiri.writeConfig("icon", "deskbar")

var spacer10 = panel.addWidget("org.kde.latte.spacer")
spacer10.currentConfigGroup = ["General"]
spacer10.writeConfig("lengthPixels", "4")
spacer10.writeConfig("lengthType", "Pixels")

panel.addWidget("org.kde.plasma.notifications")

var spacer11 = panel.addWidget("org.kde.latte.spacer")
spacer11.currentConfigGroup = ["General"]
spacer11.writeConfig("lengthPixels", "9")
spacer11.writeConfig("lengthType", "Pixels")

var dock = new Panel

dock.location = "bottom";
dock.height = 64;

dock.minimumLength = gridUnit;
dock.width = gridUnit;

dock.alignment = "center";
dock.hiding = "windowscover";

var result = ["applications:nemo.desktop", "preferred://browser"]
for (const i of ["vlc.desktop", "libreoffice-startcenter.desktop", "org.kde.kwrite.desktop", "org.kde.koko.desktop", "org.kde.plasma-systemmonitor.desktop", "org.gnome.Geary.desktop", "feren-store.desktop"]) {
    if (applicationExists(i)) {
        result.push("applications:"+i);
    }
}
var icontasks = dock.addWidget("org.kde.plasma.icontasks")
icontasks.currentConfigGroup = ["General"]
icontasks.writeConfig("iconSpacing", "0")
icontasks.writeConfig("launchers", result)
icontasks.reloadConfig();

var kickoff = dock.addWidget("P-Connor.PlasmaDrawer")
kickoff.currentConfigGroup = ["General"]
kickoff.writeConfig("appIconSize", "64")
kickoff.writeConfig("customButtonImage", "app-launcher")
kickoff.writeConfig("maxNumberColumns", "8")
kickoff.writeConfig("showSystemActions", false)
kickoff.writeConfig("useCustomButtonImage", true)
kickoff.writeConfig("useDirectoryIcons", true)
kickoff.currentConfigGroup = ["Shortcuts"]
kickoff.writeConfig("global", "Alt+F1")

var spacer12 = dock.addWidget("org.kde.latte.spacer")
spacer12.currentConfigGroup = ["General"]
spacer12.writeConfig("lengthPixels", "2")
spacer12.writeConfig("lengthType", "Pixels")

dock.addWidget("org.kde.latte.separator")

var spacer13 = dock.addWidget("org.kde.latte.spacer")
spacer13.currentConfigGroup = ["General"]
spacer13.writeConfig("lengthPixels", "2")
spacer13.writeConfig("lengthType", "Pixels")

var downloads = dock.addWidget("org.kde.plasma.folder")
downloads.currentConfigGroup = ["General"]
downloads.writeConfig("labelMode", "0")
downloads.writeConfig("viewMode", "1")
downloads.writeConfig("renameInline", false)
downloads.writeConfig("url", "~/Downloads")

var spacer14 = dock.addWidget("org.kde.latte.spacer")
spacer14.currentConfigGroup = ["General"]
spacer14.writeConfig("lengthPixels", "4")
spacer14.writeConfig("lengthType", "Pixels")

dock.addWidget("org.kde.plasma.trash")

var desktopsArray = desktopsForActivity(currentActivity());
for( var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = 'org.kde.image';
    desktopsArray[j].currentConfigGroup = Array("General");
    desktopsArray[j].writeConfig("iconSize", "2");
    desktopsArray[j].writeConfig("alignment", "1");
    desktopsArray[j].writeConfig("arrangement", "1");
    desktopsArray[j].writeConfig("sortMode", "1");
    desktopsArray[j].writeConfig("sortDirsFirst", true);
    desktopsArray[j].writeConfig("toolTips", true);
    desktopsArray[j].writeConfig("selectionMarkers", true);
    desktopsArray[j].writeConfig("renameInline", true);
    desktopsArray[j].writeConfig("popups", true);
    desktopsArray[j].writeConfig("previews", true);
    desktopsArray[j].reloadConfig();
}

plasma.loadSerializedLayout(layout);
