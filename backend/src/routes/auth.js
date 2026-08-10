import { Router } from 'express';

import { cookieOptions, requireAuth, sessionCookie } from '../middleware/auth.js';

// MVP credentials. The users table exists so this can become a real lookup
// later without reshaping the API.
const USERNAME = 'user';
const PASSWORD = 'password';

export const authRouter = Router();

authRouter.post('/login', (req, res) => {
  const { username, password } = req.body ?? {};

  if (username !== USERNAME || password !== PASSWORD) {
    res.status(401).json({ error: 'Invalid username or password' });
    return;
  }

  res.cookie(sessionCookie, username, { ...cookieOptions, signed: true });
  res.json({ username });
});

authRouter.post('/logout', (req, res) => {
  res.clearCookie(sessionCookie, cookieOptions);
  res.status(204).end();
});

authRouter.get('/me', requireAuth, (req, res) => {
  res.json({ username: req.username });
});
