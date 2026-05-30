import { jest } from '@jest/globals';

jest.unstable_mockModule('../src/config/db.config.js', () => ({
  default: jest.fn(),
}));

const { default: request } = await import('supertest');
const { default: app } = await import('../src/app.js');

describe('Health Check', () => {
  it('GET /api/v1/health should return ok', async () => {
    const res = await request(app).get('/api/v1/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
  });
});

describe('404 Handler', () => {
  it('should return 404 for unknown routes', async () => {
    const res = await request(app).get('/api/v1/unknown');
    expect(res.status).toBe(404);
  });
});
