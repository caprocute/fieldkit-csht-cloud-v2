<template>
    <StandardLayout>
        <div class="container">
            <router-link :to="{ name: 'adminMain' }" class="link">{{ $t("admin.backBtn") }}</router-link>

            <div class="delete-user">
                <div v-if="deletion.failed" class="notification failed">{{ $t("admin.deleteForm.failed") }}</div>

                <div v-if="deletion.success" class="notification success">{{ $t("admin.deleteForm.success") }}</div>

                <form id="delete-user-form" @submit.prevent="deleteUser">
                    <h2>{{ $t("admin.deleteUser") }}</h2>
                    <div>
                        <TextField v-model="deletionForm.email" :label="$tc('admin.deleteForm.form.password.required')" />
                        <div class="validation-errors" v-if="$v.deletionForm.email.$error">
                            <div v-if="!$v.deletionForm.email.required">{{ $t("admin.deleteForm.email.required") }}</div>
                            <div v-if="!$v.deletionForm.email.email">{{ $t("admin.deleteForm.email.valid") }}</div>
                        </div>
                    </div>
                    <div>
                        <TextField v-model="deletionForm.password" :label="$tc('admin.deleteForm.form.password.label')" type="password" />
                        <div class="validation-errors" v-if="$v.deletionForm.password.$error">
                            <div v-if="!$v.deletionForm.password.required">{{ $t("admin.deleteForm.password.required") }}</div>
                            <div v-if="!$v.deletionForm.password.min">{{ $t("admin.deleteForm.password.valid") }}</div>
                        </div>
                    </div>
                    <button class="form-save-button" type="submit">{{ $t("admin.deleteForm.button") }}</button>
                </form>
            </div>

            <div class="clear-tnc">
                <div v-if="tnc.failed" class="notification failed">{{ $t("admin.tnc.failed") }}</div>

                <div v-if="tnc.success" class="notification success">{{ $t("admin.tnc.success") }}</div>

                <form id="clear-tnc-form" @submit.prevent="clearTermsAndConditions">
                    <h2>{{ $t("admin.tnc.clear") }}</h2>
                    <div>
                        <TextField v-model="tncForm.email" :label="$tc('admin.tnc.form.email.label')" />
                        <div class="validation-errors" v-if="$v.tncForm.email.$error">
                            <div v-if="!$v.tncForm.email.required">{{ $t("admin.tnc.form.email.required") }}</div>
                            <div v-if="!$v.tncForm.email.email">{{ $t("admin.tnc.form.email.valid") }}</div>
                        </div>
                    </div>
                    <button class="form-save-button" type="submit">{{ $t("admin.tnc.form.button") }}</button>
                </form>
            </div>
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import Vue from "vue";
import StandardLayout from "../StandardLayout.vue";
import CommonComponents from "@/views/shared";

import { required, email, minLength } from "vuelidate/lib/validators";

export default Vue.extend({
    name: "AdminMain",
    components: {
        StandardLayout,
        ...CommonComponents,
    },
    props: {},
    data: () => {
        return {
            deletionForm: {
                email: "",
                password: "",
            },
            tncForm: {
                email: "",
            },
            deletion: {
                success: false,
                failed: false,
            },
            tnc: {
                success: false,
                failed: false,
            },
        };
    },
    validations: {
        deletionForm: {
            email: {
                required,
                email,
            },
            password: {
                required,
                min: minLength(10),
            },
        },
        tncForm: {
            email: {
                required,
                email,
            },
        },
    },
    methods: {
        deleteUser(this: any) {
            this.$v.deletionForm.$touch();
            if (this.$v.deletionForm.$pending || this.$v.deletionForm.$error) {
                return;
            }

            return this.$confirm({
                message: `Are you sure? This operation cannot be undone.`,
                button: {
                    no: "No",
                    yes: "Yes",
                },
                callback: (confirm) => {
                    if (confirm) {
                        return this.$services.api.adminDeleteUser(this.form).then(
                            () => {
                                this.deletion.success = true;
                                this.deletion.failed = false;
                            },
                            () => {
                                this.deletion.failed = true;
                                this.deletion.success = false;
                            }
                        );
                    }
                },
            });
        },
        clearTermsAndConditions(this: any) {
            this.$v.tncForm.$touch();
            if (this.$v.tncForm.$pending || this.$v.tncForm.$error) {
                return;
            }

            return this.$confirm({
                message: `Are you sure? This operation cannot be undone.`,
                button: {
                    no: "No",
                    yes: "Yes",
                },
                callback: (confirm) => {
                    if (confirm) {
                        return this.$services.api.adminClearTermsAndConditions(this.tncForm).then(
                            () => {
                                this.tnc.success = true;
                                this.tnc.failed = false;
                            },
                            () => {
                                this.tnc.failed = true;
                                this.tnc.success = false;
                            }
                        );
                    }
                },
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
.delete-user {
    width: 400px;
    text-align: left;
}
.form-save-button {
    margin-top: 50px;
    width: 300px;
    height: 45px;
    background-color: var(--color-secondary);
    border: none;
    color: white;
    font-size: 18px;
    font-weight: 600;
    border-radius: 5px;
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
</style>
