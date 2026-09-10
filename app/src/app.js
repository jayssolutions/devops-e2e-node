const express = require("express");
const client = require("prom-client");

const app = express();
app.use(express.json());

client.collectDefaultMetrics();

const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2, 5]
});

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on("finish", () => {
    end({
      method: req.method,
      route: req.path,
      status_code: res.statusCode
    });
  });
  next();
});

app.get("/", (_req, res) => {
  res.json({
    service: "devops-e2e-node-app",
    status: "ok",
    hostname: process.env.HOSTNAME || "unknown"
  });
});

app.get("/health", (_req, res) => {
  res.status(200).json({ status: "healthy" });
});

app.get("/ready", (_req, res) => {
  res.status(200).json({ status: "ready" });
});

app.get("/metrics", async (_req, res) => {
  res.set("Content-Type", client.register.contentType);
  res.end(await client.register.metrics());
});

app.get("/error", (_req, res) => {
  res.status(500).json({ error: "simulated error for monitoring tests" });
});

module.exports = app;
