import { w as writable } from "./index.js";
function getInitialUser() {
  return null;
}
function createAuthStore() {
  const initial = getInitialUser();
  const { subscribe, set, update } = writable(initial);
  return {
    subscribe,
    login: (user) => {
      set(user);
    },
    logout: () => {
      set(null);
    },
    isAuthenticated: () => {
      let authenticated = false;
      subscribe((user) => {
        authenticated = user !== null;
      })();
      return authenticated;
    }
  };
}
const auth = createAuthStore();
export {
  auth as a
};
