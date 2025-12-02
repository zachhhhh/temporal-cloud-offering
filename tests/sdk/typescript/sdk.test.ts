import { Connection, Client, WorkflowHandle } from "@temporalio/client";

const TEMPORAL_ADDRESS = "localhost:7233";
const NAMESPACE = "default";

describe("Temporal TypeScript SDK Tests", () => {
  let client: Client;
  let connection: Connection;

  beforeAll(async () => {
    connection = await Connection.connect({ address: TEMPORAL_ADDRESS });
    client = new Client({ connection, namespace: NAMESPACE });
  });

  afterAll(async () => {
    await connection.close();
  });

  describe("Connection Tests", () => {
    test("should connect to Temporal server", async () => {
      expect(connection).toBeDefined();
      console.log("✅ Connected to Temporal server");
    });

    test("should have valid client", async () => {
      expect(client).toBeDefined();
      console.log("✅ Client initialized");
    });
  });

  describe("Namespace Tests", () => {
    test("should describe namespace", async () => {
      const desc = await client.workflowService.describeNamespace({
        namespace: NAMESPACE,
      });
      expect(desc.namespaceInfo?.name).toBe(NAMESPACE);
      console.log(`✅ Namespace '${NAMESPACE}' exists`);
    });
  });

  describe("Workflow List Tests", () => {
    test("should list workflows", async () => {
      const workflows = client.workflow.list();
      let count = 0;
      for await (const wf of workflows) {
        count++;
        if (count >= 5) break; // Limit to 5
      }
      console.log(`✅ Listed ${count} workflows`);
    });
  });

  describe("Workflow Service Tests", () => {
    test("should get system info", async () => {
      const info = await client.workflowService.getSystemInfo({});
      expect(info).toBeDefined();
      console.log("✅ Got system info");
    });

    test("should list task queues", async () => {
      // This is a basic connectivity test
      const resp = await client.workflowService.describeTaskQueue({
        namespace: NAMESPACE,
        taskQueue: { name: "test-queue", kind: 1 },
      });
      expect(resp).toBeDefined();
      console.log("✅ Task queue API accessible");
    });
  });
});
