<template>
    <StandardLayout
        :viewingProjects="true"
        :viewingProject="displayProject"
        :disableScrolling="activityVisible"
        @sidebar-toggle="
            $nextTick(() => {
                layoutChanges++;
            })
        "
    >
        <div class="container-wrap">
            <template v-if="displayProject">
                <DoubleHeader
                    :title="isAdministrator ? displayProject.name : null"
                    :subtitle="isAdministrator ? $t('project.dashboard') : null"
                    :backTitle="$tc(partnerCustomization.nav.project.back.label)"
                    backRoute="projects"
                    v-if="displayProject && !bigMap"
                >
                    <div class="activity-button" v-if="isAdministrator" v-on:click="onActivityToggle">
                        <i class="icon icon-notification"></i>
                        {{ $t("project.activity.button") }}
                    </div>
                </DoubleHeader>

                <div v-if="isAdministrator" v-bind:key="id">
                    <ProjectActivity
                        v-if="activityVisible"
                        :user="user"
                        :displayProject="displayProject"
                        containerClass="project-activity-floating"
                        @close="closeActivity"
                    />
                    <ProjectAdmin :user="user" :displayProject="displayProject" :userStations="stations" v-if="user" />
                </div>
                <ProjectPublic
                    v-if="!isAdministrator && displayProject && !bigMap"
                    :user="user"
                    :displayProject="displayProject"
                    :userStations="stations"
                />
            </template>
            <template v-else-if="!isBusy && displayProject !== null">
                <ForbiddenBanner
                    class="project-forbidden-banner"
                    :title="$tc('project.privateBannerTitle')"
                    :subtitle="$tc('project.privateBannerSubtitle')"
                ></ForbiddenBanner>
            </template>
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import Vue from "vue";
import CommonComponents from "@/views/shared";
import StandardLayout from "../StandardLayout.vue";
import ProjectPublic from "./ProjectPublic.vue";
import ProjectAdmin from "./ProjectAdmin.vue";
import ProjectActivity from "./ProjectActivity.vue";
import { mapState, mapGetters } from "vuex";
import * as ActionTypes from "@/store/actions";
import { DisplayProject } from "@/store";
import { GlobalState } from "@/store/modules/global";
import { ForbiddenError } from "@/api";
import { getPartnerCustomizationWithDefault, PartnerCustomization } from "@/views/shared/partners";
import { confirmLeaveWithDirtyCheck } from "@/store/modules/dirty";
import ForbiddenBanner from "@/views/shared/ForbiddenBanner.vue";

export default Vue.extend({
    name: "ProjectView",
    components: {
        ...CommonComponents,
        StandardLayout,
        ProjectPublic,
        ProjectAdmin,
        ProjectActivity,
        ForbiddenBanner,
    },
    props: {
        id: {
            required: true,
            type: Number,
        },
        forcePublic: {
            required: true,
            type: Boolean,
        },
        activityVisible: {
            type: Boolean,
            default: false,
        },
        bigMap: {
            type: Boolean,
            default: false,
        },
    },
    data: () => {
        return {
            layoutChanges: 0,
        };
    },
    computed: {
        ...mapGetters({ isAuthenticated: "isAuthenticated", isBusy: "isBusy" }),
        ...mapState({
            user: (s: GlobalState) => s.user.user,
            stations: (s: GlobalState) => Object.values(s.stations.user.stations),
            userProjects: (s: GlobalState) => Object.values(s.stations.user.projects),
        }),
        partnerCustomization(): PartnerCustomization {
            return getPartnerCustomizationWithDefault();
        },
        displayProject(): DisplayProject {
            return this.$getters.projectsById[this.id];
        },
        isAdministrator(): boolean {
            if (!this.forcePublic) {
                const p = this.$getters.projectsById[this.id];
                if (p) {
                    return !p.project.readOnly;
                }
            }
            return false;
        },
    },
    watch: {
        id() {
            return this.$store.dispatch(ActionTypes.NEED_PROJECT, { id: this.id });
        },
    },
    beforeMount() {
        return this.$store.dispatch(ActionTypes.NEED_PROJECT, { id: this.id }).catch((e) => {
            if (ForbiddenError.isInstance(e)) {
                if (!this.$store.getters.isAuthenticated) {
                    return this.$router.push({
                        name: "login",
                        params: { errorMessage: this.$t("login.privateProject").toString() },
                        query: { after: this.$route.path },
                    });
                }
            }
        });
    },
    beforeRouteLeave(to: any, from: any, next: any) {
        confirmLeaveWithDirtyCheck(() => {
            next();
        }, this);
    },
    // needed for project nav from sidebar menu (route is not changed, only route param)
    beforeRouteUpdate(to: any, from: any, next: any) {
        confirmLeaveWithDirtyCheck(() => {
            next();
        }, this);
    },
    methods: {
        goBack() {
            if (window.history.length > 1) {
                this.$router.go(-1);
            } else {
                this.$router.push("/");
            }
        },
        showStation(station) {
            return this.$router.push({ name: "mapStation", params: { id: station.id } });
        },
        onActivityToggle(this: any) {
            if (this.activityVisible) {
                return this.$router.push({ name: "viewProject", params: { id: this.id } });
            } else {
                return this.$router.push({ name: "viewProjectActivity", params: { id: this.id } });
            }
        },
        closeActivity(this: any) {
            return this.$router.push({ name: "viewProject", params: { id: this.id } });
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/layout";
@use "src/scss/mixins";
@use "src/scss/variables";

.small-arrow {
    font-size: 11px;
    float: left;
    margin: 2px 5px 0 0;
}
.projects-link {
    margin-top: 10px;
    margin-bottom: 10px;
    font-size: 14px;
    cursor: pointer;
}
.inner-container {
}
.view-container {
}
#projects-container {
    width: 890px;
    margin: 20px 0 0 0;
}
#loading {
    width: 100%;
    height: 100%;
    background-color: rgba(255, 255, 255, 0.65);
    text-align: center;
}
.no-user-message {
    float: left;
    font-size: 20px;
    margin: 40px 0 0 40px;
}
.show-link {
    text-decoration: underline;
}
.container {
    float: left;
}
.activity-button {
    border-radius: 3px;
    border: solid 1px #cccdcf;
    background-color: #ffffff;
    cursor: pointer;
    font-family: var(--font-family-bold);
    padding: 10px 22px;
    @include mixins.flex(center, center);

    body.floodnet & {
        font-family: variables.$font-family-floodnet-button;
    }

    .icon {
        margin-right: 14px;
        font-size: 17px;

        body.floodnet & {
            &:before {
                color: var(--color-dark);
            }
        }
    }
}
.project-activity-floating {
    position: absolute;
    right: 0;
    top: 70px;
    bottom: 0;
    background-color: #fcfcfc;
    border-left: 2px solid var(--color-border);
    z-index: 10;
    overflow-y: scroll;
    width: 30em;
    paddinig: 1em;

    @include mixins.bp-down(variables.$sm) {
        @include mixins.position(fixed, 55px null null 0);
        border: 0;
        width: 100%;
        padding: 20px 0;
    }
}
::v-deep .project-tag {
    margin-right: 10px;
}

::v-deep .pagination {
    > div {
        @include mixins.flex(center, ceenter);
    }

    .button {
        font-size: 13px;
        border: 0;
        margin: 0;
        transform: translateY(2px);
    }
}

::v-deep .project-forbidden-banner {
    background: #fcfcfc;
    margin: 0 auto;

    img {
        width: 28px;
    }
}
</style>
