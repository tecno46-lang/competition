require "import"
import "android.app.AlertDialog"

-- ڈائیلاگ باکس بنانا
local dialog = AlertDialog.Builder(service)

-- ٹائٹل اور میسج سیٹ کرنا
dialog.setTitle("Maintenance Notice")
dialog.setMessage("This extension is currently under maintenance. It will be available again once the work is complete. Thank you for your patience!")

-- یوزر کو کینسل کرنے سے روکنا (یعنی اسے OK پر ہی کلک کرنا ہوگا)
dialog.setCancelable(false)

-- OK بٹن اور اس کا ایکشن (ہوم سکرین پر جانا)
dialog.setPositiveButton("OK", function()
    -- 1 کا مطلب ہے GLOBAL_ACTION_HOME (ہوم سکرین پر جانے کی کمانڈ)
    service.performGlobalAction(1)
end)

-- ڈائیلاگ باکس کو شو کروانا
dialog.show()

return true