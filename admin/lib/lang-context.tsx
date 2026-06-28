"use client";

import React, { createContext, useContext, useEffect, useState } from "react";

export type Lang = "en" | "ar";

export const translations = {
  en: {
    // Common / Buttons / Feedback
    saveChanges: "Save Changes",
    cancel: "Cancel",
    delete: "Delete",
    edit: "Edit",
    search: "Search",
    add: "Add",
    refresh: "Refresh",
    loading: "Loading",
    actions: "Actions",
    status: "Status",
    date: "Date",
    yes: "Yes",
    no: "No",
    active: "Active",
    inactive: "Inactive",
    verified: "Verified",
    unverified: "Unverified",
    searchPlaceholder: "Search...",
    confirmDelete: "Are you sure you want to delete this? This cannot be undone.",
    failedToLoad: "Failed to load data",
    failedToDelete: "Failed to delete",
    failedToUpdate: "Failed to update",
    prev: "← Prev",
    next: "Next →",

    // Login Screen
    welcomeBack: "Welcome back",
    signInSubtitle: "Sign in to access your admin panel",
    email: "Email address",
    password: "Password",
    signIn: "Sign In",
    firstTimeTitle: "First time? Create the default admin account:",
    createAdminAccount: "Create Admin Account",
    koonAdmin: "Koon Admin",
    commerceDashboard: "Commerce Dashboard",

    // Sidebar / Header
    dashboard: "Dashboard",
    orders: "Orders",
    products: "Products",
    categories: "Categories",
    users: "Users",
    overview: "Overview",
    management: "Management",
    signOut: "Sign Out",
    commercePlatform: "Commerce Platform",
    adminBadge: "Admin",

    // Dashboard Page
    totalUsers: "Total Users",
    totalProducts: "Total Products",
    totalOrders: "Total Orders",
    totalRevenue: "Total Revenue",
    pendingOrders: "Pending Orders",
    activeProducts: "Active Products",
    revenueOverview: "Revenue Overview",
    last7months: "Last 7 months",
    revenue: "Revenue",
    orderStatus: "Order Status",
    noOrdersYet: "No orders yet",
    recentOrders: "Recent Orders",
    viewAll: "View All",
    orderId: "Order ID",
    customer: "Customer",
    total: "Total",

    // Users Page
    searchUsersPlaceholder: "Search by name or email...",
    allRoles: "All Roles",
    customerRole: "Customer",
    sellerRole: "Seller",
    adminRole: "Admin",
    joined: "Joined",
    user: "User",
    role: "Role",
    editUserTitle: "Edit User",
    creditBalance: "Credit Balance (SAR)",
    credit: "Credit",
    noUsersFound: "No users found",
    deactivate: "Deactivate",
    activate: "Activate",
    deleteUserConfirm: "Are you sure you want to delete this user? This cannot be undone.",

    // Products Page
    searchProductsPlaceholder: "Search products...",
    allCategories: "All Categories",
    addProduct: "Add Product",
    product: "Product",
    category: "Category",
    price: "Price",
    stock: "Stock",
    rating: "Rating",
    noProductsFound: "No products found",
    editProductTitle: "Edit Product",
    addNewProductTitle: "Add New Product",
    titleEn: "Title (English) *",
    titleAr: "Title (Arabic) *",
    descEn: "Description (EN)",
    descAr: "Description (AR)",
    priceSar: "Price (SAR) *",
    discountPrice: "Discount Price",
    imageUrls: "Image URLs (one per line)",
    createProductBtn: "Create Product",
    deleteProductConfirm: "Delete this product?",
    noCategory: "No Category",

    // Orders Page
    allOrders: "All Orders",
    pending: "Pending",
    confirmed: "Confirmed",
    processing: "Processing",
    shipped: "Shipped",
    delivered: "Delivered",
    cancelled: "Cancelled",
    itemsCount: "items",
    updateStatus: "Update Status",
    orderItemsTitle: "Order Items",
    source: "Source",
    shippingAddress: "Shipping Address",
    noOrdersFound: "No orders found",
    viewItems: "View items",

    // Categories Page
    categoriesTotal: "categories total",
    addCategory: "Add Category",
    newCategoryTitle: "New Category",
    editCategoryTitle: "Edit Category",
    nameEn: "Name (English) *",
    nameAr: "Name (Arabic) *",
    iconEmoji: "Icon (Emoji)",
    sortOrder: "Sort Order",
    noCategoriesYet: "No categories yet. Add your first one!",
    deleteCategoryConfirm: "Delete this category? Products in this category will become uncategorized.",

    // States & Cities
    statesAndCities: "States & Cities",
    states: "States",
    cities: "Cities",
    state: "State",
    city: "City",
    addState: "Add State",
    addCity: "Add City",
    editState: "Edit State",
    editCity: "Edit City",
    stateEn: "State Name (English) *",
    stateAr: "State Name (Arabic) *",
    cityEn: "City Name (English) *",
    cityAr: "City Name (Arabic) *",
    noStatesYet: "No states added yet.",
    noCitiesYet: "No cities added yet. Select a state to add cities.",
    deleteStateConfirm: "Delete this state? All cities in this state will also be deleted.",
    deleteCityConfirm: "Delete this city?",
    selectState: "Select State",
    imageUrl: "Image URL",
    paymentMethods: "Payment Methods",
    addPaymentMethod: "Add Payment Method",
    editPaymentMethodTitle: "Edit Payment Method",
    addNewPaymentMethodTitle: "Add New Payment Method",
    noPaymentMethodsYet: "No payment methods added yet.",
    deletePaymentMethodConfirm: "Are you sure you want to delete this payment method? This cannot be undone.",
    detailsEn: "Instructions / Details (EN) *",
    detailsAr: "Instructions / Details (AR) *",
    fieldsJson: "Dynamic Fields JSON (e.g. [{\"key\":\"bank\",\"label_en\":\"Bank\",\"label_ar\":\"البنك\"}])",
    imageUrlLabel: "Image URL (optional)",
  },
  ar: {
    // Common / Buttons / Feedback
    saveChanges: "حفظ التغييرات",
    cancel: "إلغاء",
    delete: "حذف",
    edit: "تعديل",
    search: "بحث",
    add: "إضافة",
    refresh: "تحديث",
    loading: "جاري التحميل...",
    actions: "الإجراءات",
    status: "الحالة",
    date: "التاريخ",
    yes: "نعم",
    no: "لا",
    active: "نشط",
    inactive: "غير نشط",
    verified: "موثق",
    unverified: "غير موثق",
    searchPlaceholder: "بحث...",
    confirmDelete: "هل أنت متأكد من الحذف؟ لا يمكن التراجع عن هذا الإجراء.",
    failedToLoad: "فشل تحميل البيانات",
    failedToDelete: "فشل عملية الحذف",
    failedToUpdate: "فشل عملية التحديث",
    prev: "السابق →",
    next: "← التالي",

    // Login Screen
    welcomeBack: "مرحباً بعودتك",
    signInSubtitle: "سجل الدخول للوصول إلى لوحة التحكم الخاصة بك",
    email: "البريد الإلكتروني",
    password: "كلمة المرور",
    signIn: "تسجيل الدخول",
    firstTimeTitle: "أول مرة هنا؟ أنشئ حساب المشرف الافتراضي:",
    createAdminAccount: "إنشاء حساب المشرف",
    koonAdmin: "كون أدمن",
    commerceDashboard: "لوحة تحكم التجارة",

    // Sidebar / Header
    dashboard: "لوحة التحكم",
    orders: "الطلبات",
    products: "المنتجات",
    categories: "التصنيفات",
    users: "المستخدمين",
    overview: "نظرة عامة",
    management: "الإدارة",
    signOut: "تسجيل الخروج",
    commercePlatform: "منصة التجارة",
    adminBadge: "مشرف",

    // Dashboard Page
    totalUsers: "إجمالي المستخدمين",
    totalProducts: "إجمالي المنتجات",
    totalOrders: "إجمالي الطلبات",
    totalRevenue: "إجمالي الإيرادات",
    pendingOrders: "الطلبات المعلقة",
    activeProducts: "المنتجات النشطة",
    revenueOverview: "نظرة عامة على الإيرادات",
    last7months: "آخر 7 أشهر",
    revenue: "الإيرادات",
    orderStatus: "حالة الطلبات",
    noOrdersYet: "لا توجد طلبات بعد",
    recentOrders: "الطلبات الأخيرة",
    viewAll: "عرض الكل",
    orderId: "رقم الطلب",
    customer: "العميل",
    total: "الإجمالي",

    // Users Page
    searchUsersPlaceholder: "البحث بالاسم أو البريد الإلكتروني...",
    allRoles: "جميع الأدوار",
    customerRole: "عميل",
    sellerRole: "بائع",
    adminRole: "مشرف",
    joined: "تاريخ الانضمام",
    user: "المستخدم",
    role: "الدور",
    editUserTitle: "تعديل المستخدم",
    creditBalance: "رصيد الائتمان (ريال)",
    credit: "الرصيد",
    noUsersFound: "لم يتم العثور على مستخدمين",
    deactivate: "تعطيل",
    activate: "تنشيط",
    deleteUserConfirm: "هل أنت متأكد من رغبتك في حذف هذا المستخدم؟ لا يمكن التراجع عن هذا الإجراء.",

    // Products Page
    searchProductsPlaceholder: "البحث عن المنتجات...",
    allCategories: "جميع التصنيفات",
    addProduct: "إضافة منتج",
    product: "المنتج",
    category: "التصنيف",
    price: "السعر",
    stock: "المخزون",
    rating: "التقييم",
    noProductsFound: "لم يتم العثور على منتجات",
    editProductTitle: "تعديل المنتج",
    addNewProductTitle: "إضافة منتج جديد",
    titleEn: "الاسم (بالإنجليزي) *",
    titleAr: "الاسم (بالعربي) *",
    descEn: "الوصف (بالإنجليزي)",
    descAr: "الوصف (بالعربي)",
    priceSar: "السعر (ريال) *",
    discountPrice: "السعر بعد الخصم",
    imageUrls: "روابط الصور (رابط في كل سطر)",
    createProductBtn: "إنشاء المنتج",
    deleteProductConfirm: "هل تريد حذف هذا المنتج؟",
    noCategory: "بدون تصنيف",

    // Orders Page
    allOrders: "جميع الطلبات",
    pending: "معلق",
    confirmed: "مؤكد",
    processing: "قيد المعالجة",
    shipped: "تم الشحن",
    delivered: "تم التوصيل",
    cancelled: "ملغي",
    itemsCount: "منتجات",
    updateStatus: "تحديث الحالة",
    orderItemsTitle: "منتجات الطلب",
    source: "المصدر",
    shippingAddress: "عنوان الشحن",
    noOrdersFound: "لم يتم العثور على طلبات",
    viewItems: "عرض المنتجات",

    // Categories Page
    categoriesTotal: "إجمالي التصنيفات",
    addCategory: "إضافة تصنيف",
    newCategoryTitle: "تصنيف جديد",
    editCategoryTitle: "تعديل التصنيف",
    nameEn: "الاسم (بالإنجليزي) *",
    nameAr: "الاسم (بالعربي) *",
    iconEmoji: "الأيقونة (إيموجي)",
    sortOrder: "ترتيب الفرز",
    noCategoriesYet: "لا توجد تصنيفات بعد. أضف تصنيفك الأول!",
    deleteCategoryConfirm: "هل تريد حذف هذا التصنيف؟ جميع المنتجات في هذا التصنيف ستصبح بدون تصنيف.",

    // States & Cities
    statesAndCities: "المناطق والمدن",
    states: "المناطق",
    cities: "المدن",
    state: "المنطقة",
    city: "المدينة",
    addState: "إضافة منطقة",
    addCity: "إضافة مدينة",
    editState: "تعديل المنطقة",
    editCity: "تعديل المدينة",
    stateEn: "اسم المنطقة (بالإنجليزي) *",
    stateAr: "اسم المنطقة (بالعربي) *",
    cityEn: "اسم المدينة (بالإنجليزي) *",
    cityAr: "اسم المدينة (بالعربي) *",
    noStatesYet: "لم يتم إضافة مناطق بعد.",
    noCitiesYet: "لم يتم إضافة مدن بعد. اختر منطقة لإضافة مدن إليها.",
    deleteStateConfirm: "حذف هذه المنطقة؟ سيتم حذف جميع المدن التابعة لها أيضاً.",
    deleteCityConfirm: "حذف هذه المدينة؟",
    selectState: "اختر المنطقة",
    imageUrl: "رابط الصورة",
    paymentMethods: "طرق الدفع",
    addPaymentMethod: "إضافة طريقة دفع",
    editPaymentMethodTitle: "تعديل طريقة الدفع",
    addNewPaymentMethodTitle: "إضافة طريقة دفع جديدة",
    noPaymentMethodsYet: "لم يتم إضافة طرق دفع بعد.",
    deletePaymentMethodConfirm: "هل أنت متأكد من رغبتك في حذف طريقة الدفع هذه؟ لا يمكن التراجع عن هذا الإجراء.",
    detailsEn: "التعليمات / التفاصيل (بالإنجليزي) *",
    detailsAr: "التعليمات / التفاصيل (بالعربي) *",
    fieldsJson: "حقول ديناميكية JSON (مثال: [{\"key\":\"bank\",\"label_en\":\"Bank\",\"label_ar\":\"البنك\"}])",
    imageUrlLabel: "رابط الصورة (اختياري)",
  }
};

interface LangContextType {
  lang: Lang;
  setLang: (lang: Lang) => void;
  t: (key: keyof typeof translations.en) => string;
}

const LangContext = createContext<LangContextType>({
  lang: "ar",
  setLang: () => {},
  t: (key) => key,
});

export function LangProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>("ar");

  useEffect(() => {
    // 1. Check local storage
    const saved = localStorage.getItem("admin_lang") as Lang | null;
    if (saved === "en" || saved === "ar") {
      setLangState(saved);
      document.documentElement.dir = saved === "ar" ? "rtl" : "ltr";
      document.documentElement.lang = saved;
      return;
    }

    // 2. Check browser locale
    if (typeof navigator !== "undefined" && navigator.language) {
      const locale = navigator.language.toLowerCase();
      if (locale.startsWith("en")) {
        setLangState("en");
        document.documentElement.dir = "ltr";
        document.documentElement.lang = "en";
        return;
      }
    }

    // 3. Fallback to Arabic
    setLangState("ar");
    document.documentElement.dir = "rtl";
    document.documentElement.lang = "ar";
  }, []);

  const setLang = (newLang: Lang) => {
    setLangState(newLang);
    localStorage.setItem("admin_lang", newLang);
    document.documentElement.dir = newLang === "ar" ? "rtl" : "ltr";
    document.documentElement.lang = newLang;
  };

  const t = (key: keyof typeof translations.en): string => {
    const dict = translations[lang] || translations.ar;
    const val = dict[key] || translations.en[key] || key;
    return val;
  };

  return (
    <LangContext.Provider value={{ lang, setLang, t }}>
      {children}
    </LangContext.Provider>
  );
}

export const useLang = () => useContext(LangContext);
