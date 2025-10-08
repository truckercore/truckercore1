import type { NextApiRequest, NextApiResponse } from 'next';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'GET') {
    // TODO: Replace with DB fetch
    res.status(200).json([]);
  } else if (req.method === 'POST') {
    const expense = req.body;
    // TODO: Replace with DB create
    res.status(201).json(expense);
  } else {
    res.status(405).json({ message: 'Method not allowed' });
  }
}
