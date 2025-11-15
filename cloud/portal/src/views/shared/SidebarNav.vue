<template>
    <div class="container-side" v-bind:class="{ active: !sidebar.narrow, scrollable: isScrollable }">
        <div class="sidebar-header">
            <router-link :to="{ name: 'root' }">
                <Logo />
            </router-link>
        </div>
        <a v-if="!partnerCustomization().sidebarNarrow" class="sidebar-trigger" v-on:click="toggleSidebar">
            <img alt="Menu icon" src="@/assets/icon-menu.svg" width="32" height="22" />
        </a>
        <div id="inner-nav">
            <LanguageSelector class="hide-desktop"></LanguageSelector>
            <div v-if="!isPartnerCustomisationEnabled()" class="nav-section">
                <router-link :to="{ name: 'projects' }">
                    <div class="nav-label">
                        <i class="icon icon-projects"></i>
                        <span v-bind:class="{ selected: viewingProjects }">{{ $t("layout.side.projects.title") }}</span>
                    </div>
                </router-link>
                <div v-for="project in projects" v-bind:key="project.id">
                    <router-link
                        :to="{ name: 'viewProject', params: { id: project.id } }"
                        class="nav-link"
                        v-bind:class="{ selected: viewingProject && viewingProject.id === project.id }"
                        @click.native="closeMenuOnMobile()"
                    >
                        {{ project.name }}
                    </router-link>
                </div>
            </div>

            <div class="nav-section" v-if="stations.length > 0">
                <router-link :to="{ name: 'mapAllStations' }" @click.native="onStationsClick">
                    <div class="nav-label">
                        <i class="icon icon-stations"></i>
                        <span v-bind:class="{ selected: viewingStations }"><StationOrSensor /></span>
                    </div>
                </router-link>
                <!-- TODO: stations clipped until sidebar navigation is reworked -->
                <div :class="{ 'nl-narrow': sidebar.narrow }" v-for="station in clippedStations" v-bind:key="station.id">
                    <span
                        class="nav-link"
                        v-on:click="showStation(station)"
                        v-bind:class="{ selected: viewingStations && viewingStation && viewingStation.id === station.id }"
                    >
                        {{ station.name }}
                    </span>
                </div>
                <div v-if="isAuthenticated && stations.length == 0" class="nav-link">
                    <StationOrSensor stationsKey="layout.side.stations.empty" sensorsKey="layout.side.sensors.empty" />
                </div>
            </div>
        </div>
        <div class="sidebar-header sidebar-compass">
            <router-link :to="{ name: 'root' }">
                <i role="img" class="icon" :class="narrowSidebarLogoIconClass" :aria-label="narrowSidebarLogoAlt"></i>
            </router-link>
        </div>
    </div>
</template>

<script lang="ts">
import Vue, { PropType } from "vue";
import Logo from "@/views/shared/Logo.vue";
import {
    StationOrSensor,
    interpolatePartner,
    isCustomisationEnabled,
    getPartnerCustomizationWithDefault,
    PartnerCustomization,
} from "./partners";
import { DisplayProject, DisplayStation } from "@/store";
import LanguageSelector from "@/views/shared/LanguageSelector.vue";

export default Vue.extend({
    name: "SidebarNav",
    components: {
        LanguageSelector,
        Logo,
        StationOrSensor,
    },
    props: {
        viewingProject: { type: Object, default: null },
        viewingStation: { type: Object, default: null },
        viewingProjects: { type: Boolean, default: false },
        viewingStations: { type: Boolean, default: false },
        isAuthenticated: { type: Boolean, required: true },
        stations: {
            type: Array as PropType<DisplayStation[]>,
            required: true,
        },
        projects: {
            type: Array as PropType<DisplayProject[]>,
            required: true,
        },
        narrow: {
            type: Boolean,
            default: false,
        },
        clipStations: {
            type: Boolean,
            default: false,
        },
    },
    mounted(): void {
        const desktopBreakpoint = 1040;
        const windowAny: any = window;
        const resizeObserver = new windowAny.ResizeObserver((entries) => {
            if (entries[0].contentRect.width < desktopBreakpoint) {
                if (!this.sidebar.narrow) {
                    this.sidebar.narrow = true;
                }
            }
        });

        resizeObserver.observe(document.querySelector("body"));
    },
    data(): {
        sidebar: {
            narrow: boolean;
        };
        narrowSidebarLogoIconClass: string;
        narrowSidebarLogoAlt: string;
    } {
        return {
            sidebar: {
                narrow: window.screen.availWidth <= 1040 || this.narrow,
            },
            narrowSidebarLogoIconClass: interpolatePartner("icon-logo-narrow-"),
            narrowSidebarLogoAlt: interpolatePartner("layout.logo.") + ".alt",
        };
    },
    watch: {
        $route(to, _from): void {
            if (to.name === "viewProjectBigMap" || to.name === "root") {
                this.sidebar.narrow = true;
            }
        },
    },
    computed: {
        clippedStations(): DisplayStation[] {
            if (this.clipStations) {
                return this.stations.slice(0, 10);
            } else {
                return this.stations;
            }
        },
        isScrollable() {
            return true;
        },
    },
    methods: {
        onStationsClick(): void {
            this.$emit("sidebar-toggle");
            this.closeMenuOnMobile();
        },
        showStation(station: DisplayStation): void {
            this.$emit("show-station", station);
            this.closeMenuOnMobile();
        },
        closeMenuOnMobile(): void {
            if (window.screen.availWidth < 1040) {
                this.sidebar.narrow = true;
            }
        },
        toggleSidebar(): void {
            this.sidebar.narrow = !this.sidebar.narrow;
            this.$emit("sidebar-toggle");
        },
        openSidebar(): void {
            this.sidebar.narrow = false;
            this.$emit("sidebar-toggle");
        },
        closeSidebar(): void {
            this.sidebar.narrow = true;
            this.$emit("sidebar-toggle");
        },
        isPartnerCustomisationEnabled(): boolean {
            return isCustomisationEnabled();
        },
        partnerCustomization(): PartnerCustomization {
            return getPartnerCustomizationWithDefault();
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.container-side {
    @include mixins.flex();
    flex-direction: column;
    position: relative;
    background: #fff;
    width: 65px;
    flex: 0 0 65px;
    transition: all 0.25s;
    box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.28);
    z-index: variables.$z-index-menu;

    &.active {
        width: 240px;
        flex: 0 0 240px;
    }

    &.scrollable {
        max-height: 100vh;
    }

    @include mixins.bp-down(variables.$md) {
        width: 0;
        background: #fff;
        height: 100%;
        @include mixins.position(fixed, 0 null null 0);
    }
}

#sidebar-nav-narrow img {
    margin-top: 10px;
}
.sidebar-header {
    flex: 0 0 66px;
    border-bottom: 1px solid rgba(235, 235, 235, 1);
    opacity: 0;
    transition: 0.25s all;
    overflow: hidden;
    @include mixins.flex(center, center);

    @at-root .container-side.active & {
        opacity: 1;
    }

    @include mixins.bp-down(variables.$sm) {
        justify-content: flex-start;
        padding: 0 20px;
        flex: 0 0 54px;
    }

    > a {
        height: 100%;
        display: flex;
    }
}

#inner-nav {
    float: left;
    text-align: left;
    padding: 20px 15px 0;
    opacity: 0;
    visibility: hidden;
    transition: opacity 0.33s ease-in;
    overflow-y: auto;
    box-sizing: border-box;

    @at-root .container-side.active & {
        opacity: 1;
        padding: 20px 15px;
        visibility: visible;
        width: 240px;

        @include mixins.bp-down(variables.$sm) {
            padding: 0;
        }
    }
}
.nav-section {
    margin-bottom: 40px;

    @include mixins.bp-down(variables.$sm) {
        padding: 0 15px;
        margin-bottom: 20px;
    }

    > div {
        padding: 4px 0;
    }
}
.nav-label {
    @include mixins.flex(center);
    font-family: var(--font-family-bold);
    font-size: 16px;
    margin: 12px 0;
    cursor: pointer;
}
.nav-label .icon {
    vertical-align: sub;
    margin: 0 10px 0 5px;
    font-size: 16px;

    body.floodnet & {
        &:before {
            color: var(--color-dark);
        }
    }
}
.selected {
    border-bottom: 2px solid variables.$color-primary;
    height: 100%;
    display: inline-block;

    body.floodnet & {
        font-family: variables.$font-family-floodnet-bold;
    }
}
.unselected {
    display: inline-block;
}
.small-nav-text {
    font-weight: normal;
    font-size: 13px;
    margin: 20px 0 0 37px;
    display: inline-block;
}
.nl-narrow {
    display: none;
}

.nav-link {
    cursor: pointer;
    font-family: variables.$font-family-light;
    font-size: 14px;
    margin: 0 0 0 30px;
    display: inline-block;
    line-height: 1.2;

    &.selected {
        padding-bottom: 2px;
    }
}

#header-logo {
    font-size: 32px;
    @include mixins.flex(center);

    @include mixins.bp-down(variables.$md) {
        display: none;
    }
}

.sidebar-compass {
    display: flex;
    align-items: center;
    justify-content: center;
    opacity: 1;
    transform: translateX(0);
    width: 65px;
    height: 66px;
    @include mixins.position(absolute, 0 null null 0);

    @at-root .container-side.active & {
        transition: all 0.33s;
        opacity: 0;
        visibility: hidden;
        transform: translateX(100px);
    }

    @include mixins.bp-down(variables.$md) {
        display: none;
    }

    i {
        display: flex;
        align-items: center;
        font-size: 50px;

        &:before {
            color: var(--color-primary);

            body.floodnet & {
                color: var(--color-dark);
            }
        }
    }
}

.sidebar-trigger {
    transition: all 0.25s;
    cursor: pointer;
    @include mixins.position(absolute, 23px null null 77px);

    @include mixins.bp-down(variables.$md) {
        left: 10px;
        top: 16px;
    }

    .container-side.active & {
        left: 251px;

        @include mixins.bp-down(variables.$md) {
            left: 188px;
        }
    }
}
</style>
