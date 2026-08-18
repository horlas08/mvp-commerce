const getApiBase = (): string => {
  let url = "";
  if (typeof window !== "undefined") {
    if (process.env.NEXT_PUBLIC_API_URL) {
      url = process.env.NEXT_PUBLIC_API_URL;
    } else {
      const hostname = window.location.hostname;
      return `http://${hostname}:8000/api/v1`;
    }
  } else {
    url = process.env.NEXT_PUBLIC_API_URL || "http://127.0.0.1:8000/api/v1";
  }

  // Ensure it ends with /api/v1 if it doesn't already
  if (url) {
    const cleanUrl = url.endsWith("/") ? url.slice(0, -1) : url;
    if (!cleanUrl.endsWith("/api/v1")) {
      return `${cleanUrl}/api/v1`;
    }
    return cleanUrl;
  }
  return url;
};

export const API_BASE = getApiBase();

// Generic fetch helper
async function apiFetch<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch(`${API_BASE}${path}`, { ...options, headers });
  if (!res.ok) {
    if (res.status === 401 && typeof window !== "undefined") {
      localStorage.removeItem("admin_token");
      localStorage.removeItem("admin_user");
      window.location.reload();
    }
    const err = await res.json().catch(() => ({ detail: res.statusText }));
    throw new Error(err.detail || "Request failed");
  }
  return res.json();
}

// ── Auth ─────────────────────────────────────────────────────────────────────
export const adminApi = {
  login: (email: string, password: string) =>
    apiFetch<{ access_token: string; user: AdminUser }>("/admin/login", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    }),

  seedAdmin: () => apiFetch<{ message: string; email: string }>("/admin/seed-admin", { method: "POST" }),

  // Stats
  getStats: () => apiFetch<Stats>("/admin/stats"),

  // Users
  listUsers: (params?: { page?: number; limit?: number; search?: string; role?: string }) => {
    const q = new URLSearchParams();
    if (params?.page) q.set("page", String(params.page));
    if (params?.limit) q.set("limit", String(params.limit));
    if (params?.search) q.set("search", params.search);
    if (params?.role) q.set("role", params.role);
    return apiFetch<PaginatedUsers>(`/admin/users?${q}`);
  },
  updateUser: (id: string, data: Partial<{ role: string; is_active: boolean; credit_balance: number }>) =>
    apiFetch<AdminUser>(`/admin/users/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
  deleteUser: (id: string) => apiFetch(`/admin/users/${id}`, { method: "DELETE" }),

  // Products
  listProducts: (params?: { page?: number; limit?: number; search?: string; category_id?: string }) => {
    const q = new URLSearchParams();
    if (params?.page) q.set("page", String(params.page));
    if (params?.limit) q.set("limit", String(params.limit));
    if (params?.search) q.set("search", params.search);
    if (params?.category_id) q.set("category_id", params.category_id);
    return apiFetch<PaginatedProducts>(`/admin/products?${q}`);
  },
  createProduct: (data: CreateProductPayload) =>
    apiFetch<Product>("/admin/products", { method: "POST", body: JSON.stringify(data) }),
  updateProduct: (id: string, data: Partial<Product>) =>
    apiFetch<Product>(`/admin/products/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
  deleteProduct: (id: string) => apiFetch(`/admin/products/${id}`, { method: "DELETE" }),

  // Orders
  listOrders: (params?: { page?: number; limit?: number; status?: string; payment_status?: string; cart_type?: string; search?: string }) => {
    const q = new URLSearchParams();
    if (params?.page) q.set("page", String(params.page));
    if (params?.limit) q.set("limit", String(params.limit));
    if (params?.status) q.set("status", params.status);
    if (params?.payment_status) q.set("payment_status", params.payment_status);
    if (params?.cart_type) q.set("cart_type", params.cart_type);
    if (params?.search) q.set("search", params.search);
    return apiFetch<PaginatedOrders>(`/admin/orders?${q}`);
  },
  updateOrderStatus: (id: string, status: string) =>
    apiFetch(`/admin/orders/${id}/status`, { method: "PATCH", body: JSON.stringify({ status }) }),
  contactUser: (orderId: string, message: string) =>
    apiFetch(`/admin/orders/${orderId}/contact-user`, { method: "POST", body: JSON.stringify({ message }) }),

  // Manual Payments Approval
  listPendingPayments: () =>
    apiFetch<Order[]>("/admin/payments/pending"),
  approvePayment: (orderId: string) =>
    apiFetch(`/admin/payments/${orderId}/approve`, { method: "POST" }),
  rejectPayment: (orderId: string, reason?: string) =>
    apiFetch(`/admin/payments/${orderId}/reject`, { method: "POST", body: JSON.stringify({ reason }) }),

  // Refunds
  listRefunds: (params?: { page?: number; limit?: number; status?: string }) => {
    const q = new URLSearchParams();
    if (params?.page) q.set("page", String(params.page));
    if (params?.limit) q.set("limit", String(params.limit));
    if (params?.status) q.set("status", params.status);
    return apiFetch<{ refunds: RefundRequest[]; total: number }>(`/admin/refunds?${q}`);
  },
  approveRefund: (refundId: string) =>
    apiFetch(`/admin/refunds/${refundId}/approve`, { method: "POST" }),
  rejectRefund: (refundId: string, adminNote?: string) =>
    apiFetch(`/admin/refunds/${refundId}/reject`, { method: "POST", body: JSON.stringify({ admin_note: adminNote }) }),

  // Wallet
  adjustUserWallet: (userId: string, amount: number, type: "credit" | "debit", reason: string) =>
    apiFetch<AdminUser>(`/admin/users/${userId}/wallet-adjust`, { method: "POST", body: JSON.stringify({ amount, type, reason }) }),
  listWalletTransactions: (userId: string, params?: { page?: number; limit?: number }) => {
    const q = new URLSearchParams();
    if (params?.page) q.set("page", String(params.page));
    if (params?.limit) q.set("limit", String(params.limit));
    return apiFetch<{ transactions: WalletTransaction[]; total: number }>(`/admin/users/${userId}/wallet-transactions?${q}`);
  },

  // Categories
  listCategories: () => apiFetch<Category[]>("/admin/categories"),
  createCategory: (data: Partial<Category>) =>
    apiFetch<Category>("/admin/categories", { method: "POST", body: JSON.stringify(data) }),
  updateCategory: (id: string, data: Partial<Category>) =>
    apiFetch<Category>(`/admin/categories/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
  deleteCategory: (id: string) => apiFetch(`/admin/categories/${id}`, { method: "DELETE" }),

  // States & Cities
  listStates: () => apiFetch<State[]>("/admin/states"),
  createState: (data: { name_en: string; name_ar: string }) =>
    apiFetch<State>("/admin/states", { method: "POST", body: JSON.stringify(data) }),
  updateState: (id: string, data: Partial<{ name_en: string; name_ar: string }>) =>
    apiFetch<State>(`/admin/states/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
  deleteState: (id: string) => apiFetch(`/admin/states/${id}`, { method: "DELETE" }),

  listCities: (params?: { state_id?: string }) => {
    const q = new URLSearchParams();
    if (params?.state_id) q.set("state_id", params.state_id);
    return apiFetch<City[]>(`/admin/cities?${q}`);
  },
  createCity: (data: Partial<City> & { state_id: string; name_en: string; name_ar: string }) =>
    apiFetch<City>("/admin/cities", { method: "POST", body: JSON.stringify(data) }),
  updateCity: (id: string, data: Partial<City>) =>
    apiFetch<City>(`/admin/cities/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
  deleteCity: (id: string) => apiFetch(`/admin/cities/${id}`, { method: "DELETE" }),

  // Payment Methods
  listPaymentMethods: () => apiFetch<PaymentMethod[]>("/admin/payment-methods"),
  createPaymentMethod: (data: Partial<PaymentMethod>) =>
    apiFetch<PaymentMethod>("/admin/payment-methods", { method: "POST", body: JSON.stringify(data) }),
  updatePaymentMethod: (id: string, data: Partial<PaymentMethod>) =>
    apiFetch<PaymentMethod>(`/admin/payment-methods/${id}`, { method: "PATCH", body: JSON.stringify(data) }),
  deletePaymentMethod: (id: string) => apiFetch(`/admin/payment-methods/${id}`, { method: "DELETE" }),

  uploadImage: (file: File) => {
    const token = typeof window !== "undefined" ? localStorage.getItem("admin_token") : null;
    const formData = new FormData();
    formData.append("file", file);

    const headers: Record<string, string> = {};
    if (token) headers["Authorization"] = `Bearer ${token}`;

    return fetch(`${API_BASE}/admin/upload-image`, {
      method: "POST",
      headers,
      body: formData,
    }).then((res) => {
      if (!res.ok) throw new Error("Upload failed");
      return res.json() as Promise<{ image_url: string }>;
    });
  },

  // Support
  listSupportTickets: (status?: string) => {
    const q = new URLSearchParams();
    if (status) q.set("status", status);
    return apiFetch<SupportTicket[]>(`/support/admin/tickets?${q}`);
  },
  getSupportMessages: (ticketId: number) =>
    apiFetch<SupportMessage[]>(`/support/tickets/${ticketId}/messages`),
  sendSupportReply: (ticketId: number, message: string) =>
    apiFetch<SupportMessage>(`/support/tickets/${ticketId}/messages`, {
      method: "POST",
      body: JSON.stringify({ message }),
    }),
  closeSupportTicket: (ticketId: number) =>
    apiFetch<SupportTicket>(`/support/admin/tickets/${ticketId}/close`, {
      method: "POST",
    }),
  getSupportUnreadCount: () =>
    apiFetch<{ count: number }>("/support/admin/unread-count"),

  // Coupons
  listCoupons: (params?: { page?: number; limit?: number }) => {
    const q = new URLSearchParams();
    if (params?.page) q.set("page", String(params.page));
    if (params?.limit) q.set("limit", String(params.limit));
    return apiFetch<{ total: number; coupons: Coupon[] }>(`/admin/coupons?${q}`);
  },
  createCoupon: (data: CreateCouponPayload) =>
    apiFetch<Coupon>("/admin/coupons", { method: "POST", body: JSON.stringify(data) }),
  updateCoupon: (id: string, data: CreateCouponPayload) =>
    apiFetch<Coupon>(`/admin/coupons/${id}`, { method: "PUT", body: JSON.stringify(data) }),
  deleteCoupon: (id: string) =>
    apiFetch(`/admin/coupons/${id}`, { method: "DELETE" }),

  // App Settings
  listAppSettings: () =>
    apiFetch<Record<string, { key: string; value_en: string; value_ar: string }>>("/admin/settings"),
  updateAppSetting: (key: string, data: { value_en: string; value_ar: string }) =>
    apiFetch<{ key: string; value_en: string; value_ar: string }>(`/admin/settings/${key}`, {
      method: "PUT",
      body: JSON.stringify(data),
    }),
};

export interface BankAccount {
  id?: string;
  bank_name_en?: string;
  bank_name_ar?: string;
  bank_name?: string;
  account_number: string;
  account_name?: string;
  iban?: string;
  logo_url?: string;
}

export interface PaymentMethod {
  id: string;
  title_en: string;
  title_ar: string;
  description_en?: string | null;
  description_ar?: string | null;
  details_en?: string | null;
  details_ar?: string | null;
  image_url?: string | null;
  is_active: boolean;
  fields?: any[];
  raw_fields?: any[];
  bank_accounts?: BankAccount[];
  raw_bank_accounts?: BankAccount[];
}

export interface AdminUser {
  id: string;
  email: string;
  name: string;
  phone?: string;
  avatar_url?: string;
  role: string;
  is_active: boolean;
  is_verified: boolean;
  credit_balance: number;
  created_at: string;
}

export interface Stats {
  total_users: number;
  total_products: number;
  total_orders: number;
  total_revenue: number;
  pending_orders: number;
  active_products: number;
}

export interface Product {
  id: string;
  title_en: string;
  title_ar: string;
  description_en?: string;
  description_ar?: string;
  price: number;
  discount_price?: number;
  currency: string;
  images: string[];
  category_id?: string;
  stock: number;
  rating: number;
  rating_count: number;
  is_active: boolean;
  created_at: string;
}

export interface CreateProductPayload {
  title_en: string;
  title_ar: string;
  description_en?: string;
  description_ar?: string;
  price: number;
  discount_price?: number;
  category_id?: string;
  stock: number;
  images?: string[];
}

export interface Order {
  id: string;
  user_id: string;
  user_name?: string;
  user_email?: string;
  user_phone?: string;
  status: string;
  total: number;
  currency: string;
  coupon_code?: string;
  discount_amount: number;
  items: OrderItem[];
  shipping_address?: any;
  created_at: string;
  updated_at: string;
  cart_type?: string;
  shipping_type?: string;
  pickup_station_id?: string;
  allow_team_review?: boolean;
  payment_method_id?: string;
  payment_status?: string;
  payment_proof_url?: string;
  payment_fields?: any;
  notes?: string;
}

export interface OrderItem {
  id: string;
  product_id?: string;
  title: string;
  price: number;
  quantity: number;
  image_url?: string;
  source: string;
  external_url?: string;
  variant_info?: any;
}

export interface Category {
  id: string;
  name_en: string;
  name_ar: string;
  icon?: string;
  image_url?: string;
  sort_order: number;
}

export interface State {
  id: string;
  name_en: string;
  name_ar: string;
  shipping_fee: number;
  commission: number;
  free_shipping: boolean;
  no_commission: boolean;
}

export interface City {
  id: string;
  state_id: string;
  name_en: string;
  name_ar: string;
  shipping_fee: number;
  commission: number;
  free_shipping: boolean;
  no_commission: boolean;
}

export interface PaginatedUsers { users: AdminUser[]; total: number; page: number; limit: number; }
export interface PaginatedProducts { products: Product[]; total: number; page: number; limit: number; }
export interface PaginatedOrders { orders: Order[]; total: number; page: number; limit: number; }

export interface SupportTicket {
  id: number;
  user_id: string;
  title: string;
  description: string;
  status: "open" | "pending" | "closed";
  user_unread: boolean;
  admin_unread: boolean;
  created_at: string;
  updated_at: string;
  user?: {
    name: string;
    email: string;
  };
}

export interface SupportMessage {
  id: number;
  ticket_id: number;
  sender: "user" | "admin";
  message: string;
  created_at: string;
}

export interface RefundRequest {
  id: string;
  order_id: string;
  user_id: string;
  reason: string;
  status: "pending" | "approved" | "rejected" | "completed";
  admin_note?: string | null;
  created_at: string;
  updated_at: string;
  user_name?: string;
  user_email?: string;
  order_total?: number;
  order_cart_type?: string;
}

export interface WalletTransaction {
  id: string;
  user_id: string;
  amount: number;
  type: "credit" | "debit";
  reason: string;
  reference_id?: string | null;
  reference_type?: string | null;
  balance_after: number;
  created_at: string;
}

export interface Coupon {
  id: string;
  code: string;
  description?: string;
  description_en?: string;
  description_ar?: string;
  discount_type: "percentage" | "fixed";
  discount_value: number;
  min_order_amount: number;
  max_discount?: number;
  usage_limit?: number;
  used_count: number;
  is_active: boolean;
  expires_at?: string;
  applicability: "all" | "internal" | "external" | "wallet" | "funding";
}

export interface CreateCouponPayload {
  code: string;
  description_en?: string;
  description_ar?: string;
  discount_type: string;
  discount_value: number;
  min_order_amount?: number;
  max_discount?: number;
  usage_limit?: number;
  is_active?: boolean;
  expires_at?: string;
  applicability: string;
}
