require "import"
import "android.app.AlertDialog"
import "android.view.WindowManager"

-- ڈائیلاگ باکس کا بلڈر بنانا
local builder = AlertDialog.Builder(service)

-- ٹائٹل اور میسج سیٹ کرنا
builder.setTitle("Maintenance Notice")
builder.setMessage("This extension is currently under maintenance. It will be available again once the work is complete. Thank you for your patience!")

-- یوزر کو کینسل کرنے سے روکنا
builder.setCancelable(false)

-- OK بٹن اور اس کا ایکشن (ہوم سکرین پر جانا)
builder.setPositiveButton("OK", function()
    -- 1 کا مطلب ہے GLOBAL_ACTION_HOME
    service.performGlobalAction(1)
end)

-- ڈائیلاگ کو کری ایٹ (Create) کرنا
local dialog = builder.create()

-- سب سے اہم لائن: اسے Accessibility Service کی ونڈو بنانا تاکہ کریش نہ ہو
dialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)

-- اب ڈائیلاگ باکس کو شو کروانا
dialog.show()

return true
