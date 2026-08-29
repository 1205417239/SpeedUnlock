ARCHS = arm64
TARGET = iphone:clang:15.0:14.0
INSTALL_TARGET_PROCESSES = XJSKP

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SpeedUnlock
SpeedUnlock_FILES = Tweak.xm
SpeedUnlock_CFLAGS = -fobjc-arc
SpeedUnlock_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/tweak.mk
