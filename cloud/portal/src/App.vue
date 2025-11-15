<template>
    <div id="app">
        <router-view />
        <SnackBar></SnackBar>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import * as ActionTypes from "@/store/actions";
import { AuthenticationRequiredError } from "@/api";
import { getPartnerCustomization, PartnerCustomization } from "./views/shared/partners";
import SnackBar from "@/views/shared/SnackBar.vue";
import { Locales } from "@/views/shared/LanguageSelector.vue";
import moment from "moment";
import i18n from "@/i18n";
import { updateDocumentTitle } from "@/router";

export default Vue.extend({
    components: {
        SnackBar,
    },
    data() {
        return {
            Locales: Locales,
        };
    },
    async beforeMount(): Promise<void> {
        try {
            this.useSavedLocale();
            this.applyCustomClasses();
            await this.$store.dispatch(ActionTypes.INITIALIZE);
        } catch (err) {
            console.log("initialize error", err, err.stack);
        }
    },
    mounted(): void {
        this.setCustomFavicon();
    },
    computed: {
        partnerCustomization(): PartnerCustomization | null {
            return getPartnerCustomization();
        },
    },
    beforeUpdate(): void {
        this.applyCustomClasses();
    },
    watch: {
        "$i18n.locale": {
            handler() {
                this.updateDocumentTitle();
            },
            immediate: true,
        },
    },
    errorCaptured(err): boolean {
        console.log("vuejs:error-captured", JSON.stringify(err));
        if (AuthenticationRequiredError.isInstance(err)) {
            this.$router.push({ name: "login", query: { after: this.$route.path } });
            return false;
        }
        return true;
    },
    methods: {
        updateDocumentTitle(): void {
            updateDocumentTitle();
        },
        applyCustomClasses(): void {
            if (this.partnerCustomization != null) {
                document.body.classList.add(this.partnerCustomization.class);
            }
        },
        setCustomFavicon(): void {
            const faviconEl = document.getElementById("favicon") as HTMLAnchorElement;
            if (this.partnerCustomization != null) {
                faviconEl.href = window.location.origin + this.partnerCustomization.icon;
            }
        },
        changeLang(locale: Locales) {
            i18n.locale = locale;
            localStorage.setItem("locale", locale);
            moment.locale(locale);
            this.$root.$emit("language-changed");
        },
        useSavedLocale() {
            const locale = localStorage.getItem("locale") as Locales;
            if (locale) {
                this.changeLang(locale);
            }
        },
    },
});
</script>
<style lang="scss">
@use "src/scss/mixins";
@use "src/scss/typography";
@use "src/scss/icons";
@use "src/scss/layout.scss";
@use "src/scss/variables";

@use "icomoon/style.css";

html {
}

html,
body,
#app {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
}

body {
    --color-primary: #{variables.$color-fieldkit-primary};
    --color-secondary: #{variables.$color-fieldkit-secondary};
    --color-dark: #{variables.$color-fieldkit-dark};
    --color-border: #{variables.$color-fieldkit-border};
    --color-danger: #{variables.$color-fieldkit-danger};
    --font-family-medium: #{variables.$font-family-fieldkit-medium};
    --font-family-light: #{variables.$font-family-fieldkit-light};
    --font-family-bold: #{variables.$font-family-fieldkit-bold};

    text-align: center;
    margin: 0;
    padding: 0;
    flex-shrink: 0;
    color: var(--color-dark);
    font-family: var(--font-family-medium), Helvetica, Arial, sans-serif;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;

    &.floodnet {
        --color-primary: #{variables.$color-floodnet-primary};
        --color-secondary: #{variables.$color-floodnet-dark};
        --color-dark: #{variables.$color-floodnet-dark};
        --color-border: #{variables.$color-floodnet-border};
        --color-danger: #{variables.$color-fieldkit-danger};
        --font-family-medium: #{variables.$font-family-floodnet-medium};
        --font-family-light: #{variables.$font-family-floodnet-medium};
        --font-family-bold: #{variables.$font-family-floodnet-bold};
    }
}

body:not(.disable-scrolling) {
    overflow-y: scroll;
}

body.disable-scrolling {
    margin-right: 14px; /* We need width of the scrollbars! */
}

body.blue-background {
    background-color: #1b80c9;

    @include mixins.bp-down(variables.$md) {
        background-color: #fff;
    }

    &.floodnet {
        @include mixins.bp-up(variables.$md) {
            background-color: var(--color-dark);
        }
    }
}

html.map-view {
    height: 100%;
}

body.map-view {
    height: 100%;
}

a {
    text-decoration: none;
    color: inherit;
}

button {
    cursor: pointer;
    color: inherit;

    body.floodnet & {
        font-family: variables.$font-family-floodnet-button;
    }
}

.main-panel {
    width: auto;
    text-align: left;
    color: #2c3e50;
}

.main-panel h1 {
    font-size: 36px;
    margin-top: 40px;
}

h1 {
    font-family: var(--font-family-bold);
}

ul {
    margin: 0;
    padding: 0;
}

li {
    list-style-type: none;
}

.vue-treeselect__single-value {
    color: inherit;
}

.date-picker input {
    color: inherit;
}

.vue-treeselect__control {
    border: 1px solid var(--color-border);

    @include mixins.bp-down(variables.$sm) {
        border-radius: 2px;
    }
}

.vue-treeselect__control-arrow {
    @include mixins.bp-down(variables.$sm) {
        width: 11px;
        height: 11px;
    }
}

.vc-nav-item {
    color: #fff !important;

    &.is-active {
        color: var(--color-dark) !important;
    }
}

.vc-nav-header * {
    color: #fff !important;
}

.vc-popover-caret {
    @include mixins.bp-down(variables.$sm) {
        display: none !important;
    }
}

.vc-container {
    max-width: 90vw;

    .vc-text {
        white-space: break-spaces;
    }
}

.cupertino-pane-wrapper {
    .draggable {
        z-index: 10 !important;
        width: calc(100% - 60px);
    }
    .move {
        height: 3px;
        margin-top: 2px;
    }
}

#silentbox-overlay {
    z-index: 9999 !important;
}
</style>
