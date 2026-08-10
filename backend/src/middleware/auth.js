export const sessionCookie = 'kanban_session';

export const cookieOptions = {
  httpOnly: true,
  sameSite: 'lax',
  path: '/',
};

/**
 * Rejects requests without a valid session, and attaches the username to the
 * request for the routes behind it.
 *
 * cookie-parser sets a signed cookie to false when the signature does not
 * verify, so a tampered cookie fails the same check as a missing one.
 */
export function requireAuth(req, res, next) {
  const username = req.signedCookies[sessionCookie];

  if (!username) {
    res.status(401).json({ error: 'Not signed in' });
    return;
  }

  req.username = username;
  next();
}
