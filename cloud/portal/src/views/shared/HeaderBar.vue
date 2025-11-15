<template>
    <div class="header">
        <router-link :to="{ name: 'root' }">
            <Logo />
        </router-link>
        <LanguageSelector class="hide-mob"></LanguageSelector>
        <div
            class="header-account"
            :class="isAuthenticated ? 'loggedin' : ''"
            v-on:click="onAccountClick()"
            v-on:mouseenter="onAccountHover()"
            v-on:mouseleave="onAccountHoverOut()"
        >
            <div v-if="user" class="header-avatar">
                <i class="badge" v-if="numberOfUnseenNotifications > 0">
                    <span>{{ numberOfUnseenNotifications }}</span>
                </i>
                <UserPhoto v-if="user" :user="user" />
                <span v-if="isAccountHovered" class="triangle"></span>
            </div>

            <a v-if="user" class="header-account-name">{{ firstName }}</a>

            <router-link
                :to="{ name: 'login', query: { after: $route.path, params: JSON.stringify($route.query) } }"
                class="log-in"
                v-if="!isAuthenticated"
            >
                {{ $t("layout.header.login") }}
            </router-link>

            <div v-if="user" class="notifications-container" v-bind:class="{ active: isAccountHovered }">
                <header class="notifications-header">
                    <span class="notifications-header-text">{{ $t("layout.header.notifications") }}</span>
                    <div class="flex">
                        <router-link v-if="user && user.admin" :to="{ name: 'adminMain' }">
                            {{ $t("layout.header.admin") }}
                        </router-link>
                        <router-link v-if="user" :to="{ name: 'editUser' }" :title="$t('layout.header.myAccount')">
                            <img src="@/assets/icon-account.svg" :alt="$t('layout.header.myAccount')" />
                        </router-link>
                        <a class="log-out" v-if="isAuthenticated" v-on:click="logout" :title="$t('layout.header.logout')">
                            <img src="@/assets/icon-logout.svg" :alt="$t('layout.header.logout')" />
                        </a>
                    </div>
                </header>

                <template v-if="numberOfUnseenNotifications > 0">
                    <NotificationsList v-on:notification-click="notificationNavigate"></NotificationsList>

                    <footer class="notifications-footer">
                        <button v-on:click="viewAll()">{{ $t("notifications.viewAllButton") }}</button>
                        <button v-on:click="markAllSeen()">{{ $t("notifications.dismissAllButton") }}</button>
                    </footer>
                </template>
                <template v-if="numberOfUnseenNotifications === 0">
                    <div class="no-notifications">
                        <span>{{ $t("layout.header.noNotifications") }}</span>
                        <img alt="Image" src="@/assets/no-notifications.png" />
                    </div>
                </template>
            </div>
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import { mapGetters, mapState } from "vuex";
import * as ActionTypes from "@/store/actions";
import { MarkNotificationsSeen } from "@/store";
import CommonComponents from "@/views/shared";
import NotificationsList from "@/views/notifications/NotificationsList.vue";
import { GlobalState } from "@/store/modules/global";
import Logo from "@/views/shared/Logo.vue";
import { Notification } from "@/store/modules/notifications";
import { isMobile } from "@/utilities";
import LanguageSelector from "@/views/shared/LanguageSelector.vue";

export default Vue.extend({
    name: "HeaderBar",
    components: {
        LanguageSelector,
        ...CommonComponents,
        NotificationsList,
        Logo,
    },
    data(): { isAccountHovered: boolean } {
        return {
            isAccountHovered: false,
        };
    },
    computed: {
        ...mapGetters({
            isAuthenticated: "isAuthenticated",
            notifications: "notifications",
            numberOfUnseenNotifications: "numberOfUnseenNotifications",
        }),
        ...mapState({ user: (s: GlobalState) => s.user.user }),
        firstName(): string {
            if (!this.user) {
                return "";
            }
            return this.user.name.split(" ")[0];
        },
    },
    methods: {
        async logout(): Promise<void> {
            await this.$store.dispatch(ActionTypes.LOGOUT).then(() => {
                // Action handles where we go after.
            });
        },
        onAccountHover(): void {
            // console.log("hover", this.hiding, this.isAccountHovered);
            if (!isMobile()) {
                this.isAccountHovered = !this.isAccountHovered;
            }
        },
        onAccountHoverOut(): void {
            this.isAccountHovered = false;
        },
        onAccountClick(): void {
            if (isMobile()) {
                this.isAccountHovered = !this.isAccountHovered;
            }
        },
        async markAllSeen(): Promise<void> {
            await this.$store.dispatch(new MarkNotificationsSeen([]));
        },
        viewAll() {
            return this.$router.push({ name: "notifications" });
        },
        notificationNavigate(notification: Notification) {
            if (notification.projectId) {
                return this.$router
                    .push({
                        name: "viewProject",
                        params: { id: notification.projectId },
                        hash: `#comment-id-${notification.postId}`,
                    })
                    .then(() => {
                        this.$store.dispatch(new MarkNotificationsSeen([notification.notificationId]));
                    })
                    .catch((err) => {
                        console.log(err);
                        return;
                    });
            }
            if (notification.bookmark) {
                return this.$router
                    .push({
                        name: "exploreBookmark",
                        query: { bookmark: notification.bookmark },
                        hash: `#comment-id-${notification.postId}`,
                    })
                    .then(() => {
                        this.$store.dispatch(new MarkNotificationsSeen([notification.notificationId]));
                    })
                    .catch((err) => {
                        console.log(err);
                        return;
                    });
            }
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.header {
    background: #fff;
    box-shadow: 0 1px 4px 0 rgba(0, 0, 0, 0.12);
    width: 100%;
    float: left;
    padding: 0 10px;
    box-sizing: border-box;
    z-index: variables.$z-index-header;
    flex: 0 0 65px;
    padding-right: 85px;
    @include mixins.flex(center, flex-end);

    @include mixins.bp-down(variables.$lg) {
        padding-right: 14px;
    }

    @include mixins.bp-down(variables.$md) {
        padding: 0 10px;
        height: 54px;
        position: fixed;

        ::v-deep + * {
            margin-top: 54px;
        }
    }

    > a {
        display: flex;
        align-items: center;
    }

    &-account {
        text-align: right;
        position: relative;
        height: 100%;
        @include mixins.flex(center);

        &-name {
            font-size: 16px;
            font-weight: 500;
            z-index: variables.$z-index-top;

            @include mixins.bp-down(variables.$sm) {
                display: none;
            }
        }
    }

    .loggedin {
        &:after {
            content: "";
            background: url("../../assets/icon-chevron-dropdown.svg") no-repeat center center;
            width: 10px;
            height: 10px;
            transition: all 0.33s;
            transform: translateY(-50%);
            cursor: pointer;
            @include mixins.position(absolute, 50% null null calc(100% + 5px));

            @include mixins.bp-down(variables.$lg) {
                right: 0;
            }

            @include mixins.bp-down(variables.$sm) {
                display: none;
            }
        }

        &:hover {
            &:after {
                transform: rotate(180deg) translateY(50%);
            }
        }
    }

    &-menu {
        overflow: hidden;
        background: #fff;
        transition: opacity 0.25s, max-height 0.33s;
        opacity: 0;
        visibility: hidden;
        text-align: left;
        min-width: 183px;
        box-sizing: border-box;
        box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.5);
        z-index: -1;
        @include mixins.position(absolute, calc(100% - 5px) 70px null null);

        @include mixins.bp-down(variables.$lg) {
            @include mixins.position(fixed, 60px 10px null unset);
        }

        &.active {
            opacity: 1 !important;
            visibility: visible;
            border: solid 1px #e9e9e9;
            z-index: initial;
        }
    }
    &-avatar {
        position: relative;
        cursor: pointer;
    }
}

::v-deep .triangle {
    @include mixins.position(absolute, null null -10px 5px);
    z-index: variables.$z-index-top;
    width: 0;
    height: 0;
    border-style: solid;
    border-width: 0 15px 12px 15px;
    border-color: transparent transparent #fff transparent;
    filter: drop-shadow(0px -2px 1px rgba(0, 0, 0, 0.1));

    @include mixins.bp-down(variables.$md) {
        left: 2px;
        border-width: 0 12px 9px 12px;
    }
}

::v-deep .default-user-icon {
    margin: 0 10px 0 0;

    @include mixins.bp-down(variables.$md) {
        width: 30px;
        height: 30px;
    }

    @include mixins.bp-down(variables.$sm) {
        margin: 0;
    }
}

.badge {
    @include mixins.position(absolute, -5px null null -7px);
    height: 20px;
    width: 20px;
    background: var(--color-primary);
    border-radius: 50%;

    > * {
        @include mixins.position(absolute, 5px null null 50%);
        transform: translateX(-50%);
        color: #fff;
        font-size: 11px;
        font-style: normal;
        font-family: variables.$font-family-bold;

        body.floodnet & {
            color: var(--color-dark);
        }
    }
}

.flex {
    display: flex;
}

button {
    padding: 0;
    border: 0;
    outline: 0;
    box-shadow: none;
    cursor: pointer;
    background: transparent;
}

.notifications {
    &-header {
        @include mixins.flex(center, space-between);
        height: 50px;
        border-bottom: solid 1px #d8dce0;
        margin-bottom: 15px;
        letter-spacing: 0.1px;
        padding: 0 13px;

        &-text {
            font-size: 20px;
        }
    }

    &-footer {
        border-top: solid 1px #d8dce0;
        margin-top: auto;
        @include mixins.flex(center, space-between);

        button {
            padding: 13px 15px 10px 15px;
            font-size: 16px;
            font-weight: 900;
            color: #2c3e50;
        }
    }

    &-container {
        background: #fff;
        transition: opacity 0.25s, max-height 0.33s;
        text-align: left;
        box-sizing: border-box;
        box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.5);
        border: solid 1px #e9e9e9;
        max-height: 80vh;
        flex-direction: column;
        width: 320px;
        z-index: -1;
        opacity: 0;
        visibility: hidden;
        @include mixins.flex();
        @include mixins.position(absolute, calc(100% + 1px) 30px null null);

        @include mixins.bp-down(variables.$lg) {
            top: 100%;
            right: 30px;
        }

        @include mixins.bp-down(variables.$sm) {
            right: -10px;
            height: calc(100vh - 55px);
        }

        @include mixins.bp-down(variables.$xs) {
            width: 100vw;
            right: -10px;
        }

        &.active {
            opacity: 1 !important;
            visibility: visible;
            z-index: initial;
        }

        a {
            padding: 8px 12px;
            font-size: 14px;
            display: block;
            user-select: none;
        }

        > ul {
            overflow-y: auto;
            //padding: 0 10px;
        }
    }
}

#header-logo {
    display: none;

    @include mixins.bp-down(variables.$md) {
        @include mixins.position(fixed, null null null 50%);
        @include mixins.flex(center);
        font-size: 32px;
        height: 50px;
        transform: translateX(-50%);
    }

    @include mixins.bp-down(variables.$xs) {
        font-size: 26px;
    }
}

.no-notifications {
    text-align: center;
    padding: 0 30px 30px;

    img {
        width: 100%;
        margin-top: 15px;
    }
}
</style>
