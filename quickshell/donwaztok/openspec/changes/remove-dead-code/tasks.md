## 1. Delete unreferenced QML

- [ ] 1.1 `modules/common/functions/`: DateUtils.qml NotificationUtils.qml ObjectUtils.qml 
- [ ] 1.2 `modules/common/models/`: AdaptedMaterialScheme.qml IndexModel.qml 
- [ ] 1.3 `modules/common/models/quickToggles/`: AntiFlashbangToggle.qml AudioToggle.qml BluetoothToggle.qml CloudflareWarpToggle.qml ColorPickerToggle.qml DarkModeToggle.qml IdleInhibitorToggle.qml MicToggle.qml NetworkToggle.qml NotificationToggle.qml PowerProfilesToggle.qml QuickToggleModel.qml ScreenSnipToggle.qml 
- [ ] 1.4 `modules/common/utils/`: ImageDownloaderProcess.qml 
- [ ] 1.5 `modules/common/widgets/`: AddressBar.qml AddressBreadcrumb.qml CalendarView.qml CliphistImage.qml ClippedFilledCircularProgress.qml ClippedProgressBar.qml ConfigRow.qml ConfigSelectionArray.qml ConfigSlider.qml ConfigSpinBox.qml ConfigSwitch.qml ContentSubsectionLabel.qml ContentSubsection.qml DialogListItem.qml DirectoryIcon.qml DragManager.qml Favicon.qml FlowButtonGroup.qml Graph.qml IconAndTextToolbarButton.qml IconToolbarButton.qml LightDarkPreferenceButton.qml MaterialCookie.qml MaterialLoadingIndicator.qml MaterialShape.qml MaterialShapeWrappedMaterialSymbol.qml MaterialTextArea.qml MenuButton.qml NavigationRailButton.qml NavigationRailExpandButton.qml NavigationRail.qml NavigationRailTabArray.qml NoticeBox.qml NotificationActionButton.qml NotificationAppIcon.qml NotificationGroupExpandButton.qml NotificationGroup.qml NotificationItem.qml NotificationListView.qml OptionalMaterialSymbol.qml PagePlaceholder.qml PointingHandLinkHover.qml PopupToolTip.qml Revealer.qml RippleButtonWithIcon.qml ScrollEdgeFade.qml SecondaryTabBar.qml SecondaryTabButton.qml SelectionDialog.qml SelectionGroupButton.qml SineCookie.qml StyledBlurEffect.qml StyledComboBox.qml StyledDropShadow.qml StyledImage.qml StyledIndeterminateProgressBar.qml StyledSpinBox.qml StyledTextArea.qml StyledTextInput.qml ThumbnailImage.qml ToolbarButton.qml ToolbarTextField.qml VerticalButtonGroup.qml VibrantToolbarButton.qml WaveVisualizer.qml WeekRow.qml WindowDialogSectionHeader.qml WindowDialogSeparator.qml WindowDialogSlider.qml 
- [ ] 1.6 `modules/common/widgets/widgetCanvas/`: AbstractWidget.qml WidgetCanvas.qml 
- [ ] 1.7 `modules/controlcenter/appearance/sections/`: ColorSchemeSection.qml ColorVariantSection.qml 
- [ ] 1.8 `modules/controlcenter/components/`: ConnectedButtonGroup.qml 
- [ ] 1.9 `modules/controlcenter/network/`: EthernetPane.qml EthernetSettings.qml WirelessPane.qml WirelessSettings.qml 
- [ ] 1.10 `services/`: BluetoothStatus.qml HyprlandXkb.qml KeyringStorage.qml LatexRenderer.qml MprisController.qml ResourceUsage.qml SystemInfo.qml TimerService.qml Ydotool.qml 
- [ ] 1.11 `modules/common/widgets/shapes/` (whole folder: vendored material-shapes library and examples; only dead widgets import it)

## 2. Delete orphan scripts

- [ ] 2.1 `scripts/files/fm.py` (replaced by `bin/fm` from `fm-rs`) and the unused `script` property in `services/shell/FileManagerService.qml`
- [ ] 2.2 `scripts/colors/random/` (`random_konachan_wall.sh`, `random_osu_wall.sh`)
- [ ] 2.3 `scripts/hyprland/get_keybinds.py`

## Verification

- [ ] 4.1 Re-run the reference check before deleting (a file referenced since this list was made stays)
- [ ] 4.2 `qs log -c donwaztok` after reload: no `is not a type` / `module … is not installed` errors
- [ ] 4.3 Open bar, dashboard (all tabs), launcher, sidebar, utilities, session, control center (all panes), lock, file manager, text editor, OSD, region selector, cheatsheet
