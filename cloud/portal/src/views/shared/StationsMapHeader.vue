<template>
    <div class="map-header">
        <div class="photo-container">
            <img src="@/assets/fieldkit_project.png" class="project-photo project-image photo" alt="FieldKit Project" />
        </div>
        <div class="detail-container">
            <div>
                <div class="flex flex-al-center">
                    <h1 class="detail-title">
                        <template v-if="project">{{ project.name }}</template>
                        <template v-else>{{ $t("map.header.title") }}</template>
                    </h1>
                </div>
                <div class="detail-description">
                    <template v-if="project">
                        <router-link :to="{ name: 'viewProject', params: { id: project.id } }">
                            {{ project.id }}
                            {{ $t("map.header.viewProjectDashboard") }} >
                        </router-link>
                    </template>
                    <template v-else>
                        {{ $t("map.header.subtitle") }}
                    </template>
                </div>
            </div>
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import { DisplayProject } from "@/store";

export default Vue.extend({
    name: "StationsMapHeader",
    components: {},
    props: {
        project: {
            type: Object as () => DisplayProject,
            required: false,
        },
    },
    data() {
        return {};
    },
    computed: {},
});
</script>

<style scoped lang="scss">
@use "src/scss/project";
@use "src/scss/global";
@use "src/scss/mixins";
@use "src/scss/variables";

.map-header {
    display: none;
    width: 100%;
    box-sizing: border-box;
    background-color: #fcfcfc;
    box-shadow: 0 1px 4px 0 rgba(0, 0, 0, 0.12);
    text-align: left;
    padding: 24px 20px;
    z-index: variables.$z-index-top;

    @include mixins.bp-up(variables.$md) {
        display: flex;
    }

    body.floodnet & {
        background-color: #f6f9f8;

        @include mixins.bp-down(variables.$sm) {
            background-color: #ffffff;
        }
    }

    @include mixins.bp-down(variables.$sm) {
        width: 100%;
        padding: 10px;
        top: 52px;
        align-items: center;
        border-left-width: 0;
        border-right-width: 0;
        z-index: 10;

        &:after {
            content: "";
            width: 0;
            height: 0;
            border-width: 8px 8px 0 8px;
            border-color: #d8d8d8 transparent transparent transparent;
            border-style: solid;
            margin-left: auto;
        }

        &.mobile-expanded:after {
            border-width: 0 8px 8px 8px;
            border-color: transparent transparent #d8d8d8 transparent;
        }
    }

    ::v-deep .link {
        color: variables.$color-primary;
        font-size: 12px;
        letter-spacing: 0.07px;
        text-decoration: initial;
        display: block;

        @include mixins.bp-down(variables.$sm) {
            font-family: variables.$font-family-medium;
            font-size: 14px;
        }

        body.floodnet & {
            @include mixins.bp-up(variables.$sm) {
                color: variables.$color-dark;
            }
        }
    }
}

.detail-container {
    overflow: hidden;
}

::v-deep .detail-title {
    font-family: variables.$font-family-bold;
    font-size: 18px;
    margin-top: 0;
    margin-bottom: 2px;
    margin-right: 10px;
    text-overflow: ellipsis;
    overflow: hidden;
    white-space: nowrap;

    @include mixins.bp-down(variables.$sm) {
        margin-bottom: 0;
    }
}

::v-deep .detail-description {
    font-family: var(--font-family-light);
    font-size: 14px;
    max-height: 35px;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
    margin-right: 10px;

    .link {
        display: inline-block;
        font-size: 14px;
        text-decoration: underline;
    }

    @include mixins.bp-down(variables.$sm) {
        display: none;
    }
}

::v-deep .detail-links {
    @include mixins.bp-down(variables.$sm) {
        position: absolute;
        top: 51px;
        left: 0;
        background-color: #fff;
        width: 100%;
        padding: 12px 10px 7px 10px;
        opacity: 0;
        visibility: hidden;
        box-sizing: border-box;
        box-shadow: 0 1px 4px 0 rgba(0, 0, 0, 0.12);

        &.mobile-visible {
            opacity: 1;
            visibility: visible;
        }

        .link {
            color: variables.$color-dark;
            border: 1px solid variables.$color-dark;
            border-radius: 25px;
            padding: 6px 12px;
            display: inline-block;
            margin-bottom: 5px;
        }
    }
}

.photo-container {
    flex: 0 0 38px;
    height: 38px;
    margin: 0 12px 0 0;

    img {
        border-radius: 2px;
    }

    @include mixins.bp-down(variables.$sm) {
        flex-basis: 30px;
        height: 30px;
    }
}
</style>
