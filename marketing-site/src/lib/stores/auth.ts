import { writable } from "svelte/store";
import { browser } from "$app/environment";

export interface User {
  email: string;
  name: string;
  provider: "google" | "microsoft" | "email";
  avatar?: string;
}

function getCookie(name: string): string | null {
  if (!browser) return null;
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) return parts.pop()?.split(";").shift() || null;
  return null;
}

function deleteCookie(name: string) {
  if (browser) {
    document.cookie = `${name}=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT`;
  }
}

function getInitialUser(): User | null {
  if (!browser) return null;

  // First check localStorage
  const stored = localStorage.getItem("auth_user");
  if (stored) {
    try {
      return JSON.parse(stored);
    } catch {
      localStorage.removeItem("auth_user");
    }
  }

  // Then check auth cookie (set by OAuth callback)
  const authCookie = getCookie("auth");
  if (authCookie) {
    try {
      const user = JSON.parse(decodeURIComponent(authCookie));
      // Sync to localStorage
      localStorage.setItem("auth_user", JSON.stringify(user));
      return user;
    } catch {
      deleteCookie("auth");
    }
  }

  return null;
}

function createAuthStore() {
  const initial = getInitialUser();
  const { subscribe, set, update } = writable<User | null>(initial);

  return {
    subscribe,
    login: (user: User) => {
      if (browser) {
        localStorage.setItem("auth_user", JSON.stringify(user));
      }
      set(user);
    },
    logout: () => {
      if (browser) {
        localStorage.removeItem("auth_user");
        deleteCookie("auth");
      }
      set(null);
    },
    isAuthenticated: () => {
      let authenticated = false;
      subscribe((user) => {
        authenticated = user !== null;
      })();
      return authenticated;
    },
  };
}

export const auth = createAuthStore();
