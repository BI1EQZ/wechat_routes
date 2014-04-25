THEOS_DEVICE_IP = 192.168.2.2
include theos/makefiles/common.mk

BUNDLE_NAME = supery_wechat
supery_wechat_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries
include $(THEOS)/makefiles/bundle.mk

TWEAK_NAME = supery_wechat
supery_wechat_FILES = Tweak.xm
supery_wechat_FRAMEWORKS = UIKit Foundation MapKit CoreLocation QuartzCore
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 MicroMessenger"
