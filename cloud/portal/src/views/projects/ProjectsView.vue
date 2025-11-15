<template>
    <StandardLayout :viewingProjects="true">
        <div class="projects-view">
            <div v-if="isAuthenticated" class="container mine">
                <div class="header">
                    <h1 v-if="isAuthenticated">{{ $t("projects.title.mine") }}</h1>
                    <h1 v-if="!isAuthenticated">{{ $t("projects.title.anonymous") }}</h1>
                    <div id="add-project" v-on:click="addProject" v-if="isAuthenticated">
                        <i class="icon icon-plus-round"></i>
                        <span>{{ $t("projects.add") }}</span>
                    </div>
                </div>

                <template v-if="userProjects.length > 0 || pendingProjectInvites.length > 0">
                    <ProjectThumbnails :projects="userProjects" />
                    <ProjectThumbnails :projects="pendingProjectInvites" :invited="true" v-if="pendingProjectInvites.length > 0" />
                </template>
                <template v-else>
                    <div class="no-projects-message">
                        {{ $t("projects.noUserProjects") }}
                    </div>
                </template>
            </div>
            <div class="container community">
                <div class="header">
                    <h1>{{ $t("projects.title.community") }}</h1>
                </div>
                <ProjectThumbnails :projects="publicProjects" />
            </div>
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import Vue from "vue";
import { mapState, mapGetters } from "vuex";
import StandardLayout from "../StandardLayout.vue";
import ProjectThumbnails from "./ProjectThumbnails.vue";
import { StationsState } from "@/store/modules/stations";
import * as ActionTypes from "@/store/actions";

export default Vue.extend({
    name: "ProjectsView",
    components: {
        StandardLayout,
        ProjectThumbnails,
    },
    computed: {
        ...mapGetters({
            isAuthenticated: "isAuthenticated",
            pendingProjectInvites: "pendingProjectInvites",
        }),
        ...mapState({
            userProjects: (s: { stations: StationsState }) => Object.values(s.stations.user.projects),
            publicProjects: (s: { stations: StationsState }) => Object.values(s.stations.community.projects),
        }),
    },
    async mounted(): Promise<void> {
        if (this.isAuthenticated) {
            await this.$store.dispatch(ActionTypes.NEED_PROJECT_INVITES);
        }
    },
    methods: {
        goBack() {
            if (window.history.length > 1) {
                this.$router.go(-1);
            } else {
                this.$router.push("/");
            }
        },
        addProject() {
            this.$router.push({ name: "addProject" });
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.projects-view {
    display: flex;
    flex-direction: column;
    padding: 10px 72px 60px;
    text-align: left;

    @include mixins.bp-down(variables.$lg) {
        padding: 10px 45px 60px;
    }

    @include mixins.bp-down(variables.$sm) {
        padding: 0 20px 30px;
    }

    @include mixins.bp-down(variables.$xs) {
        padding: 0 10px 30px;
    }
}

.container.mine {
    border-bottom: 1px solid var(--color-border);
}

.container .header {
    display: flex;
    flex-direction: row;
    align-items: center;
    margin-bottom: 30px;
    margin-top: 40px;

    @include mixins.bp-down(variables.$lg) {
        margin-bottom: 20px;
        margin-top: 30px;
    }

    @include mixins.bp-down(variables.$xs) {
        margin-bottom: 25px;
        margin-top: 20px;
    }

    h1 {
        font-size: 36px;
        margin: 0;

        @include mixins.bp-down(variables.$lg) {
            font-size: 32px;
        }

        @include mixins.bp-down(variables.$xs) {
            font-size: 24px;
        }
    }
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
#add-project {
    margin-left: auto;
    cursor: pointer;
    font-size: 16px;
    @include mixins.flex(center);

    i {
        margin-right: 7px;
        margin-top: -3px;
    }
}
.no-projects-message {
    font-size: 18px;
    margin-bottom: 20px;
}
</style>
