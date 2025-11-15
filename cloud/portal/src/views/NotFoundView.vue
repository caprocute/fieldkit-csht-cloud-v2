<template>
    <StandardLayout>
        <div class="not-found-container">
            <img src="@/assets/404.svg" alt="404" class="not-found-img" />
            <div class="not-found-content">
                <h1>{{ $t("notFound.title") }}</h1>
                <p>{{ $t("notFound.message") }}</p>
                <router-link to="/" class="button-solid not-found-button">{{ $t("notFound.toDashboard") }}</router-link>
            </div>
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import Vue from "vue";
import StandardLayout from "./StandardLayout.vue";

export default Vue.extend({
    name: "NotFoundView",
    components: {
        StandardLayout,
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.not-found {
    &-container {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        background-color: white;
        height: 100%;
        text-align: center;
        padding: 40px 20px;
    }

    &-img {
        width: 100%;
        max-width: 500px;
        margin-top: -100px;
        margin-bottom: 20px;
    }

    &-content {
        max-width: 540px;
        margin: 0 auto;
    }

    &-button {
        margin-top: 30px;
        display: inline-flex;
        align-items: center;
        justify-content: center;

        @include mixins.bp-down(variables.$sm) {
            width: 100%;
            margin-top: 20px;
        }
    }
}

h1 {
    font-size: 36px;
    margin-bottom: 20px;
    color: var(--color-dark);

    @include mixins.bp-down(variables.$sm) {
        font-size: 28px;
    }
}

p {
    font-size: 18px;
    line-height: 1.5;
    margin-bottom: 30px;
    color: var(--color-dark);

    @include mixins.bp-down(variables.$sm) {
        font-size: 16px;
        margin-bottom: 20px;
    }
}
</style>
