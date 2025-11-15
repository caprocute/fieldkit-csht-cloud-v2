<template>
    <StandardLayout>
        <div class="container">
            <div class="menu">
                <router-link :to="{ name: 'adminUsers' }" class="link"><h2>Users</h2></router-link>
                <router-link :to="{ name: 'adminStations' }" class="link"><h2>Stations</h2></router-link>
                <router-link :to="{ name: 'adminModeration' }" class="link">
                    <h2>{{ $t("admin.moderation") }}</h2>
                </router-link>
            </div>

            <div class="backup-upload form-container">
                <h2>Upload Backup</h2>

                <form @submit.prevent="saveForm" class="form" v-if="!busy">
                    <div class="form-group">
                        <input type="file" @change="upload" />
                    </div>
                    <div class="form-group">
                        <button class="button-solid" type="submit">Upload</button>
                    </div>
                </form>

                <div v-if="uploaded">
                    <div v-if="uploaded.errors" class="form-group">
                        <div class="label">Errors:</div>
                        {{ uploaded.errors }}
                    </div>
                    <div v-if="uploaded.deviceId" class="form-group">
                        <div class="label">Device ID:</div>
                        {{ uploaded.deviceId }}
                    </div>
                    <div v-if="uploaded.generationId" class="form-group">
                        <div class="label">Generation ID:</div>
                        {{ uploaded.generationId }}
                    </div>
                    <div v-if="uploaded.deviceName" class="form-group">
                        <div class="label">Device Name:</div>
                        {{ uploaded.deviceName }}
                    </div>
                    <div v-if="uploaded.records" class="form-group">
                        <div class="label">Records:</div>
                        {{ uploaded.records }}
                    </div>
                </div>
            </div>

            <div class="status" v-if="status">
                <h2>{{ $t("admin.serverLogs.heading") }}</h2>
                <table>
                    <tbody>
                        <tr>
                            <td>
                                <a
                                    href="https://code.conservify.org/logs-viewer/?range=3600&query=tag:fkprd%20OR%20tag:fkdev"
                                    target="_blank"
                                >
                                    {{ $t("admin.serverLogs.all") }}
                                </a>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <a href="https://code.conservify.org/logs-viewer/?range=86400&query=zaplevel:error" target="_blank">
                                    {{ $t("admin.serverLogs.errors") }}
                                </a>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <a
                                    href="https://code.conservify.org/logs-viewer/?range=86400&query=_exists_:data_processed&include=device_id,user_id,meta_errors,data_errors,meta_processed,data_processed,blocks,station_name"
                                    target="_blank"
                                >
                                    {{ $t("admin.serverLogs.ingestions") }}
                                </a>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <a
                                    href="https://code.conservify.org/logs-viewer/?range=86400&query=message:%22station%20conflict%22"
                                    target="_blank"
                                >
                                    {{ $t("admin.serverLogs.conflicts") }}
                                </a>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <div class="status" v-if="status">
                <h2>Server Details</h2>
                <table>
                    <tbody>
                        <tr>
                            <th>{{ $t("admin.status.server") }}</th>
                            <td>{{ status.serverName }}</td>
                        </tr>
                        <tr>
                            <th>{{ $t("admin.status.tag") }}</th>
                            <td>{{ status.tag }}</td>
                        </tr>
                        <tr>
                            <th>{{ $t("admin.status.name") }}</th>
                            <td>{{ status.name }}</td>
                        </tr>
                        <tr>
                            <th>{{ $t("admin.status.git") }}</th>
                            <td>{{ status.git.hash }}</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import Vue from "vue";
import StandardLayout from "../StandardLayout.vue";
import CommonComponents from "@/views/shared";
import { PortalDeployStatus } from "@/api";

type Uploaded = {
    deviceId: string;
    generationId: string;
    deviceName: string;
    errors: [string];
    records: [number];
};

export default Vue.extend({
    name: "AdminMain",
    components: {
        StandardLayout,
        ...CommonComponents,
    },
    data(): {
        status: PortalDeployStatus | null;
        form: { file: any };
        busy: boolean;
        uploaded: Uploaded | null;
    } {
        return {
            status: null,
            form: { file: null },
            busy: false,
            uploaded: null,
        };
    },
    async mounted(): Promise<void> {
        await this.$services.api.getStatus().then((status) => {
            this.status = status;
        });
    },
    methods: {
        upload(this: any, ev) {
            console.log("upload", ev.target.files);
            const file = ev.target.files[0];
            this.form.file = file;
        },
        async saveForm() {
            console.log("save-form", this.form);
            this.busy = true;
            await this.$services.api
                .adminUploadBackup(this.form)
                .then((uploaded: any) => {
                    console.log(uploaded);
                    this.uploaded = uploaded;
                })
                .finally(() => {
                    this.busy = false;
                });
        },
    },
});
</script>

<style scoped>
.container {
    display: flex;
    flex-direction: column;
    padding: 20px;
    text-align: left;
}
.notification.success {
    margin-top: 20px;
    margin-bottom: 20px;
    padding: 20px;
    border: 2px;
    border-radius: 4px;
}
.notification.success {
    background-color: #d4edda;
}
.notification.failed {
    background-color: #f8d7da;
}
.link {
    display: block;
    margin-bottom: 1em;
    font-size: 18px;
    font-weight: bold;
}
.backup-upload {
    margin-top: 1em;
    margin-bottom: 1em;

    .label {
        font-weight: bold;
        font-size: 14pt;
    }

    .form-group {
        margin-bottom: 1em;
    }
}
</style>
