import express from 'express';
import { getResponse } from './';

const router = express.Router();

router.post('/', (req, res) => {
  const { message } = req.body;
  const response = getResponse(message); 
  res.json(response);
});

export default router;