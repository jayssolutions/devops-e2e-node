const request = require("supertest");
const app = require("../src/app");

describe("DevOps e2e-node app", () => {
  test("GET / returns 200", async () => {
    const response = await request(app).get("/");
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe("ok");
  });

  test("GET /health returns healthy", async () => {
    const response = await request(app).get("/health");
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe("healthy");
  });

  test("GET /metrics exposes Prometheus metrics", async () => {
    const response = await request(app).get("/metrics");
    expect(response.statusCode).toBe(200);
    expect(response.text).toContain("process_cpu");
  });
});
