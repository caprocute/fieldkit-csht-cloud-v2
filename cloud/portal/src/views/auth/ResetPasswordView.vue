<template>
    <div class="form-container">
        <Logo class="form-header-logo"></Logo>
        <form class="form" @submit.prevent="save">
            <template v-if="!success && !failed">
                <h1 class="form-title">{{ $t("reset.form.title") }}</h1>

                <div class="form-group">
                    <TextField v-model="form.password" label="Password" type="password" />

                    <div class="form-errors" v-if="$v.form.password.$error">
                        <div v-if="!$v.form.password.required">{{ $t("reset.form.password.required") }}</div>
                        <div v-if="!$v.form.password.min">{{ $t("reset.form.password.valid") }}</div>
                    </div>
                </div>

                <div class="form-group">
                    <TextField v-model="form.passwordConfirmation" label="Confirm Password" type="password" />

                    <div class="form-errors" v-if="$v.form.passwordConfirmation.$error">
                        <div v-if="!$v.form.passwordConfirmation.required">{{ $t("reset.form.passwordConfirm.required") }}</div>
                        <div v-if="!$v.form.passwordConfirmation.sameAsPassword">{{ $t("reset.form.passwordConfirm.required") }}</div>
                    </div>
                </div>
                <button class="form-submit" v-on:click="save">Reset</button>
                <div>
                    <router-link :to="{ name: 'login' }" class="form-link">{{ $t("reset.form.backButton") }}</router-link>
                </div>
            </template>
            <template v-if="success">
                <img src="@/assets/icon-success.svg" alt="Success" class="form-header-icon" width="57px" />
                <h1 class="form-title">{{ $t("reset.form.successTitle") }}</h1>

                <router-link :to="{ name: 'login' }" class="form-link">{{ $t("reset.form.backButton") }}</router-link>
            </template>
            <template v-if="failed">
                <img src="@/assets/icon-warning-error.svg" alt="Unsuccessful" class="form-header-icon" width="57px" />
                <h1 class="form-title">{{ $t("reset.form.failedTitle") }}</h1>
                <div class="form-subtitle">{{ $t("reset.form.failedTitle") }}</div>
                <d>
                    {{ $t("reset.form.retry.please") }}
                    <a href="https://www.fieldkit.org/contact/" class="contact-link">{{ $t("reset.form.retry.contactUs") }}</a>
                    {{ $t("reset.form.retry.assistance") }}
                </d>
            </template>
        </form>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import CommonComponents from "@/views/shared";
import { required, minLength, sameAs } from "vuelidate/lib/validators";
import Logo from "@/views/shared/Logo.vue";

export default Vue.extend({
    name: "ResetPasswordView",
    components: {
        ...CommonComponents,
        Logo,
    },
    data: () => {
        return {
            form: {
                password: "",
                passwordConfirmation: "",
            },
            busy: false,
            success: false,
            failed: false,
        };
    },
    validations: {
        form: {
            password: { required, min: minLength(10) },
            passwordConfirmation: { required, min: minLength(10), sameAsPassword: sameAs("password") },
        },
    },
    methods: {
        save(this: any) {
            console.log("save");
            this.$v.form.$touch();
            if (this.$v.form.$pending || this.$v.form.$error) {
                return;
            }

            this.success = false;
            this.failed = false;
            this.busy = true;
            const payload = {
                token: this.$route.query.token,
                password: this.form.password,
            };
            return this.$services.api
                .resetPassword(payload)
                .then(() => {
                    this.success = true;
                })
                .catch(() => {
                    this.failed = true;
                })
                .finally(() => {
                    this.busy = false;
                });
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/forms.scss";
@use "src/scss/mixins";
@use "src/scss/variables";

.contact-link {
    cursor: pointer;
    font-weight: 500;
    text-decoration: underline;

    @include mixins.bp-down(variables.$xs) {
        font-size: 14px;
    }
}
</style>
