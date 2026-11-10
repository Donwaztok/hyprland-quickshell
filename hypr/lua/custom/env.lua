-- Custom environment variables
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Input method (Fcitx example)
-- hl.env("QT_IM_MODULE", "fcitx")
-- hl.env("XMODIFIERS", "@im=fcitx")
-- hl.env("SDL_IM_MODULE", "fcitx")
-- hl.env("GLFW_IM_MODULE", "ibus")
-- hl.env("INPUT_METHOD", "fcitx")

-- Wayland tearing / cursors
-- hl.env("WLR_DRM_NO_ATOMIC", "1")
-- hl.env("WLR_NO_HARDWARE_CURSORS", "1")

-- Editor
-- hl.env("EDITOR", "vim")

-- Browser video decoding on the GPU (NVDEC) through libva-nvidia-driver; pairs with Zen's user.js
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("MOZ_DISABLE_RDD_SANDBOX", "1")
