import json
import os
import re

# Set the base directory of the flutter app
APP_ROOT = "/Users/user/project/koon/koon_mobile"

replacements = [
    # splash_screen.dart
    ("lib/screens/splash/splash_screen.dart", "'Shop Globally, Delivered Locally'", "'splash_subtitle'.tr()", "splash_subtitle", "Shop Globally, Delivered Locally", "تسوق عالمياً، واستلم محلياً"),
    
    # register_screen.dart
    ("lib/screens/auth/register_screen.dart", "'Create your account to get started'", "'create_account_desc'.tr()", "create_account_desc", "Create your account to get started", "أنشئ حسابك للبدء"),
    ("lib/screens/auth/register_screen.dart", "'Name is required'", "'name_is_required'.tr()", "-", "-", "-"),
    ("lib/screens/auth/register_screen.dart", "'Email is required'", "'email_is_required'.tr()", "email_is_required", "Email is required", "البريد الإلكتروني مطلوب"),
    ("lib/screens/auth/register_screen.dart", "'Enter a valid email'", "'enter_valid_email'.tr()", "enter_valid_email", "Enter a valid email", "أدخل بريداً إلكترونياً صالحاً"),
    ("lib/screens/auth/register_screen.dart", "'Password is required'", "'password_is_required'.tr()", "password_is_required", "Password is required", "كلمة المرور مطلوبة"),
    ("lib/screens/auth/register_screen.dart", "'At least 6 characters'", "'password_min_length'.tr()", "password_min_length", "At least 6 characters", "٦ أحرف على الأقل"),
    ("lib/screens/auth/register_screen.dart", "'Passwords do not match'", "'passwords_dont_match'.tr()", "passwords_dont_match", "Passwords do not match", "كلمتا المرور غير متطابقتين"),
    
    # login_screen.dart
    ("lib/screens/auth/login_screen.dart", "'Email is required'", "'email_is_required'.tr()", "-", "-", "-"),
    ("lib/screens/auth/login_screen.dart", "'Enter a valid email'", "'enter_valid_email'.tr()", "-", "-", "-"),
    ("lib/screens/auth/login_screen.dart", "'Password is required'", "'password_is_required'.tr()", "-", "-", "-"),
    ("lib/screens/auth/login_screen.dart", "'Password must be at least 6 characters'", "'password_min_length'.tr()", "-", "-", "-"),
    
    # forgot_password_screen.dart
    ("lib/screens/auth/forgot_password_screen.dart", "'Email is required'", "'email_is_required'.tr()", "-", "-", "-"),
    ("lib/screens/auth/forgot_password_screen.dart", "'Enter a valid email'", "'enter_valid_email'.tr()", "-", "-", "-"),
    ("lib/screens/auth/forgot_password_screen.dart", "'Check your email for the reset link.'", "'check_email_reset_link'.tr()", "check_email_reset_link", "Check your email for the reset link.", "تحقق من بريدك الإلكتروني للحصول على رابط إعادة التعيين."),
    
    # webview_screen.dart
    ("lib/screens/webview/webview_screen.dart", "'Added to your cart!'", "'added_to_cart'.tr()", "-", "-", "-"),
    
    # search_screen.dart
    ("lib/screens/search/search_screen.dart", "'Search for products'", "'search_for_products'.tr()", "search_for_products", "Search for products", "البحث عن المنتجات"),
    
    # my_credit_screen.dart
    ("lib/screens/profile/my_credit_screen.dart", "'Top Up'", "'top_up'.tr()", "top_up", "Top Up", "شحن الرصيد"),
    ("lib/screens/profile/my_credit_screen.dart", "'Payment gateway loading...'", "'payment_gateway_loading'.tr()", "payment_gateway_loading", "Payment gateway loading...", "جاري تحميل بوابة الدفع..."),
    ("lib/screens/profile/my_credit_screen.dart", "'${authController.userCredit.toStringAsFixed(2)} SAR'", "'${authController.userCredit.toStringAsFixed(2)} ' + 'SAR'.tr()", "-", "-", "-"),
    
    # categories_screen.dart
    ("lib/screens/categories/categories_screen.dart", "'No categories available'", "'no_categories_available'.tr()", "no_categories_available", "No categories available", "لا توجد فئات متاحة"),
    
    # orders_screen.dart
    ("lib/screens/orders/orders_screen.dart", "'${items.length} item${items.length != 1 ? 's' : ''}'", "items.length == 1 ? 'one_item'.tr() : 'items_count'.tr(args: [items.length.toString()])", "-", "-", "-"),
    ("lib/screens/orders/orders_screen.dart", "'$total SAR'", "'$total ' + 'SAR'.tr()", "-", "-", "-"),
    
    # compare_controller.dart
    ("lib/controllers/compare_controller.dart", "'Compare List'", "'compare_list'.tr()", "-", "-", "-"),
    ("lib/controllers/compare_controller.dart", "'Product removed from compare list'", "'product_removed_compare'.tr()", "product_removed_compare", "Product removed from compare list", "تمت إزالة المنتج من قائمة المقارنة"),
    ("lib/controllers/compare_controller.dart", "'You can compare up to 4 products at a time.'", "'compare_limit_reached'.tr()", "compare_limit_reached", "You can compare up to 4 products at a time.", "يمكنك مقارنة ما يصل إلى 4 منتجات في المرة الواحدة."),
    ("lib/controllers/compare_controller.dart", "'Product added to compare list'", "'product_added_compare'.tr()", "product_added_compare", "Product added to compare list", "تمت إضافة المنتج إلى قائمة المقارنة"),
    
    # auth_controller.dart
    ("lib/controllers/auth_controller.dart", "'Success'", "'success'.tr()", "success", "Success", "نجاح"),
    ("lib/controllers/auth_controller.dart", "'Error'", "'error'.tr()", "error", "Error", "خطأ"),
    ("lib/controllers/auth_controller.dart", "'Reset link sent to your email'", "'reset_link_sent'.tr()", "reset_link_sent", "Reset link sent to your email", "تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني"),
    
    # settings_controller.dart
    ("lib/controllers/settings_controller.dart", "'${converted.toStringAsFixed(2)} SAR'", "'${converted.toStringAsFixed(2)} ' + 'SAR'.tr()", "-", "-", "-"),
    ("lib/controllers/settings_controller.dart", "'${price.toStringAsFixed(2)} SAR'", "'${price.toStringAsFixed(2)} ' + 'SAR'.tr()", "-", "-", "-"),
]

extra_translations = {
    "one_item": ("1 item", "منتج واحد"),
    "items_count": ("{} items", "{} منتجات"),
    "connection_error": ("Connection error", "خطأ في الاتصال"),
    "SAR": ("SAR", "ريال"),
    "USD": ("USD", "دولار"),
    "email_verification": ("Email Verification", "تأكيد البريد الإلكتروني"),
    "enter_verification_code": ("Enter 6-digit code", "أدخل رمز التأكيد المكون من 6 أرقام"),
    "verify": ("Verify", "تأكيد"),
    "resend_code": ("Resend Code", "إعادة إرسال الرمز"),
    "resend_in": ("Resend in {}s", "إعادة الإرسال خلال {} ثانية"),
    "verification_sent_to": ("We have sent a verification code to {}", "لقد أرسلنا رمز التأكيد إلى {}"),
    "email_verified_success": ("Email verified successfully", "تم تأكيد البريد الإلكتروني بنجاح"),
    "verification_code_sent": ("Verification code sent", "تم إرسال رمز التأكيد"),
    "change_password": ("Change Password", "تغيير كلمة المرور"),
    "current_password": ("Current Password", "كلمة المرور الحالية"),
    "new_password": ("New Password", "كلمة المرور الجديدة"),
    "confirm_new_password": ("Confirm New Password", "تأكيد كلمة المرور الجديدة"),
    "update_password": ("Update Password", "تحديث كلمة المرور"),
    "current_password_required": ("Current password is required", "كلمة المرور الحالية مطلوبة"),
    "new_password_required": ("New password is required", "كلمة المرور الجديدة مطلوبة")
}

def apply():
    modified_files = set()
    
    # Apply replacements in source code files
    for rel_path, old_str, new_str, key, en_val, ar_val in replacements:
        file_path = os.path.join(APP_ROOT, rel_path)
        if not os.path.exists(file_path):
            print(f"Warning: File not found: {file_path}")
            continue
            
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
            
        if old_str in content:
            content = content.replace(old_str, new_str)
            modified_files.add(file_path)
            
            # Ensure proper localization imports
            if "easy_localization.dart" not in content:
                # Add easy_localization import
                if "import 'package:flutter/material.dart';" in content:
                    content = content.replace(
                        "import 'package:flutter/material.dart';",
                        "import 'package:flutter/material.dart';\nimport 'package:easy_localization/easy_localization.dart';"
                    )
                elif "import 'package:get/get.dart';" in content:
                    content = content.replace(
                        "import 'package:get/get.dart';",
                        "import 'package:easy_localization/easy_localization.dart';\nimport 'package:get/get.dart';"
                    )
                else:
                    content = "import 'package:easy_localization/easy_localization.dart';\n" + content
            
            # Solve GetX / EasyLocalization .tr conflict: 'import 'package:get/get.dart';' -> 'hide Trans'
            if "import 'package:get/get.dart';" in content:
                content = content.replace(
                    "import 'package:get/get.dart';",
                    "import 'package:get/get.dart' hide Trans;"
                )
            elif "import 'package:get/get.dart' " in content and "hide Trans" not in content:
                # E.g. import 'package:get/get.dart' show ... or something, let's just make sure we handle it
                pass
                
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Applied replacement in {rel_path}")

    # Write to translation files
    en_file = os.path.join(APP_ROOT, "assets/translations/en.json")
    ar_file = os.path.join(APP_ROOT, "assets/translations/ar.json")
    
    if os.path.exists(en_file) and os.path.exists(ar_file):
        with open(en_file, "r", encoding="utf-8") as f:
            en_data = json.load(f)
        with open(ar_file, "r", encoding="utf-8") as f:
            ar_data = json.load(f)
            
        # Add replacements translations
        for _, _, _, key, en_val, ar_val in replacements:
            if key != "-":
                en_data[key] = en_val
                ar_data[key] = ar_val
                
        # Add extra translations
        for key, (en_val, ar_val) in extra_translations.items():
            en_data[key] = en_val
            ar_data[key] = ar_val
            
        with open(en_file, "w", encoding="utf-8") as f:
            json.dump(en_data, f, ensure_ascii=False, indent=2)
        with open(ar_file, "w", encoding="utf-8") as f:
            json.dump(ar_data, f, ensure_ascii=False, indent=2)
            
        print("Updated en.json and ar.json successfully.")
    else:
        print("Error: Translation json files not found.")

if __name__ == "__main__":
    apply()
