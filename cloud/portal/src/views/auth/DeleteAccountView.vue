<template>
    <div class="form-container">
        <ForbiddenBanner v-if="errorMessage" :title="errorMessage" :subtitle="$t('login.loginError')"></ForbiddenBanner>
        <Logo class="form-header-logo"></Logo>
        <div v-if="!authenticated">
            <LoginForm
                :showCreateAccount="false"
                :spoofing="false"
                :failed="failed"
                :busy="busy"
                @login="save"
                :heading="$t('deleteAccount.heading')"
                :message="$t('deleteAccount.welcome')"
            />
        </div>
        <div v-if="authenticated && !deleted">
            <form class="form" @submit.prevent="deleteAccount">
                <h1 class="form-title">{{ $t("deleteAccount.heading") }}</h1>
                <p>
                    {{ $t("deleteAccount.warning") }}
                </p>
                <div class="form-group">
                    <TextField v-model="form.email" :label="$t('login.form.email.label')" />
                    <div class="form-errors" v-if="$v.form.email.$error">
                        <div v-if="!$v.form.email.required">{{ $t("login.form.email.required") }}</div>
                        <div v-if="!$v.form.email.email">{{ $t("login.form.email.valid") }}</div>
                        <div v-if="!$v.form.email.sameAsRawValue">{{ $t("deleteAccount.sameEmail") }}</div>
                    </div>
                </div>
                <button class="form-submit" type="submit">
                    <template v-if="!busy">
                        {{ $t("deleteAccount.button") }}
                    </template>
                </button>
            </form>
        </div>
        <div v-if="deleted">
            <form class="form">
                {{ $t("deleteAccount.done") }}
            </form>
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import CommonComponents from "@/views/shared";
import LoginForm from "./LoginForm.vue";
import Logo from "../shared/Logo.vue";

import { LoginPayload } from "@/api/api";
import { ActionTypes } from "@/store";
import ForbiddenBanner from "@/views/shared/ForbiddenBanner.vue";
import { required, email, sameAs } from "vuelidate/lib/validators";

export default Vue.extend({
    components: {
        ...CommonComponents,
        LoginForm,
        Logo,
        ForbiddenBanner,
    },
    props: {
        errorMessage: {
            type: String,
            required: false,
        },
    },
    data(): {
        busy: boolean;
        failed: boolean;
        authenticated: boolean;
        deleted: boolean;
        email: string;
        form: {
            email: string;
        };
    } {
        return {
            busy: false,
            failed: false,
            authenticated: false,
            deleted: false,
            email: "",
            form: {
                email: "",
            },
        };
    },
    validations() {
        return {
            form: {
                email: {
                    required,
                    email,
                    sameAsRawValue: sameAs(function (this: any) {
                        return this.email;
                    }),
                },
            },
        };
    },
    methods: {
        async save(payload: LoginPayload): Promise<void> {
            this.busy = true;
            this.failed = false;

            await this.$store
                .dispatch(ActionTypes.LOGIN, payload)
                .then(
                    async () => {
                        await this.afterAuth(payload);
                    },
                    () => (this.failed = true)
                )
                .finally(() => {
                    this.busy = false;
                });
        },
        async afterAuth(payload): Promise<void> {
            this.email = payload.email;
            this.authenticated = true;
        },
        async deleteAccount(): Promise<void> {
            this.$v.form.$touch();
            if (this.busy || this.$v.form.$pending || this.$v.form.$error) {
                return;
            }
            await this.$services.api.deleteAccount({});
            this.deleted = true;

            await this.$store.dispatch({ type: ActionTypes.LOGOUT, skipNavigation: true });
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/forms.scss";
</style>
