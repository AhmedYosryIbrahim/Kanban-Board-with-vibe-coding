/**
 * Throws an error carrying the HTTP status the route should answer with.
 * The catch-all handler in app.js turns it into a JSON response.
 */
export function fail(status, message) {
  const error = new Error(message);
  error.status = status;
  throw error;
}
