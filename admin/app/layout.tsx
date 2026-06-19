import type { Metadata } from "next";
import { LangProvider } from "@/lib/lang-context";
import "./globals.css";

export const metadata: Metadata = {
  title: "Koon Admin Dashboard",
  description: "Professional admin dashboard for Koon Commerce Platform",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full">
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                try {
                  var saved = localStorage.getItem('admin_lang');
                  var lang = 'ar';
                  if (saved === 'en' || saved === 'ar') {
                    lang = saved;
                  } else if (typeof navigator !== 'undefined' && navigator.language) {
                    var locale = navigator.language.toLowerCase();
                    if (locale.startsWith('en')) {
                      lang = 'en';
                    }
                  }
                  document.documentElement.lang = lang;
                  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
                } catch (e) {}
              })();
            `
          }}
        />
      </head>
      <body className="min-h-full">
        <LangProvider>
          {children}
        </LangProvider>
      </body>
    </html>
  );
}
