// API base URL
export const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/v1";

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
  listOrders: (params?: { page?: number; limit?: number; status?: string }) => {
    const q = new URLSearchParams();
    if (params?.page) q.set("page", String(params.page));
    if (params?.limit) q.set("limit", String(params.limit));
    if (params?.status) q.set("status", params.status);
    return apiFetch<PaginatedOrders>(`/admin/orders?${q}`);
  },
  updateOrderStatus: (id: string, status: string) =>
    apiFetch(`/admin/orders/${id}/status`, { method: "PATCH", body: JSON.stringify({ status }) }),

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
  createCity: (data: { state_id: string; name_en: string; name_ar: string }) =>
    apiFetch<City>("/admin/cities", { method: "POST", body: JSON.stringify(data) }),
  updateCity: (id: string, data: Partial<{ state_id: string; name_en: string; name_ar: string }>) =>
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
};

// ── Types ─────────────────────────────────────────────────────────────────────
export interface PaymentMethod {
  id: string;
  title_en: string;
  title_ar: string;
  details_en?: string | null;
  details_ar?: string | null;
  image_url?: string | null;
  is_active: boolean;
  fields?: any[];
  raw_fields?: any[];
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
  status: string;
  total: number;
  currency: string;
  coupon_code?: string;
  discount_amount: number;
  items: OrderItem[];
  shipping_address?: any;
  created_at: string;
  updated_at: string;
}

export interface OrderItem {
  id: string;
  product_id?: string;
  title: string;
  price: number;
  quantity: number;
  image_url?: string;
  source: string;
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
}

export interface City {
  id: string;
  state_id: string;
  name_en: string;
  name_ar: string;
}

export interface PaginatedUsers { users: AdminUser[]; total: number; page: number; limit: number; }
export interface PaginatedProducts { products: Product[]; total: number; page: number; limit: number; }
export interface PaginatedOrders { orders: Order[]; total: number; page: number; limit: number; }
