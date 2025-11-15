import {defineConfig} from "cypress";

export default defineConfig({
    e2e: {
        defaultCommandTimeout: 10000,
        baseUrl: 'http://127.0.0.1:8082',
    },
});
