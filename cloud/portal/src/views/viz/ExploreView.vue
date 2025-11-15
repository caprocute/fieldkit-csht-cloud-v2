<template>
    <ExploreWorkspace
        v-if="visibleBookmark"
        :token="token"
        :bookmark="visibleBookmark"
        :exportsVisible="exportsVisible"
        :shareVisible="shareVisible"
        @open-bookmark="openBookmark"
        @export="exportWorkspace"
        @share="shareWorkspace"
        @event-clicked="eventClicked"
    />
</template>

<script lang="ts">
import { Bookmark, serializeBookmark, deserializeBookmark } from "./viz";

import Vue from "vue";
import ExploreWorkspace from "./ExploreWorkspace.vue";
import { confirmLeaveWithDirtyCheck } from "@/store/modules/dirty";
import { ActionTypes } from "@/store";

export default Vue.extend({
    name: "ExploreView",
    components: {
        ExploreWorkspace,
    },
    props: {
        token: {
            type: String,
            required: false,
        },
        bookmark: {
            type: Bookmark,
            required: false,
        },
        exportsVisible: {
            type: Boolean,
            default: false,
        },
        shareVisible: {
            type: Boolean,
            default: false,
        },
    },
    data(): {
        resolved: { [index: string]: Bookmark };
        bookmarkToToken: { [bookmark: string]: string };
    } {
        return {
            resolved: {},
            bookmarkToToken: {},
        };
    },
    computed: {
        visibleBookmark(): null | Bookmark {
            if (this.bookmark) {
                return this.bookmark;
            }
            if (this.token) {
                if (this.resolved[this.token]) {
                    return this.resolved[this.token];
                }
            }
            return null;
        },
    },
    watch: {
        async token(newValue: Bookmark, _oldValue: Bookmark): Promise<void> {
            console.log(`viz: bookmark-route(token):`, newValue);
            await this.refreshBookmarkFromToken();
        },
        async bookmark(newValue: Bookmark, _oldValue: Bookmark): Promise<void> {
            console.log(`viz: bookmark-route(bookmark):`, newValue);
        },
    },
    async beforeMount(): Promise<void> {
        if (this.token) {
            await this.refreshBookmarkFromToken();
        }
    },
    beforeRouteLeave(to: any, from: any, next: any) {
        confirmLeaveWithDirtyCheck(() => {
            next();
        }, this);
    },
    methods: {
        async refreshBookmarkFromToken(): Promise<void> {
            const token = this.token;
            // console.log(`viz: bookmark-resolving`, token);
            try {
                if (!this.resolved[token] && token) {
                    const savedBookmark = await this.$services.api.resolveBookmark(token);
                    console.log(`viz: bookmark-resolved`, savedBookmark);
                    Vue.set(this.resolved, token, deserializeBookmark(savedBookmark.bookmark));
                    console.log("setting permissions radoi", savedBookmark);
                    await this.$store.dispatch(ActionTypes.SET_DISCUSSION_PERMISSIONS, savedBookmark.permissions);
                } else {
                    console.log(`viz: bookmark-missing`);
                }
            } catch (error) {
                console.log("viz: bad-token", error);
            }
        },
        async openBookmark(bookmark: Bookmark): Promise<void> {
            const encoded = serializeBookmark(bookmark);
            if (!this.bookmarkToToken[encoded]) {
                // console.log(`viz: open-bookmark-saving`, encoded);
                const savedBookmark = await this.$services.api.saveBookmark(encoded);
                Vue.set(this.bookmarkToToken, encoded, savedBookmark.token);
                Vue.set(this.resolved, savedBookmark.token, bookmark);
                await this.$store.dispatch(ActionTypes.SET_DISCUSSION_PERMISSIONS, savedBookmark.permissions);
                // console.log(`viz: open-bookmark-saved`, savedBookmark.token);
            }
            await this.$router.replace({ name: "exploreShortBookmark", query: { v: this.bookmarkToToken[encoded] } });
        },
        async exportWorkspace(): Promise<void> {
            try {
                await this.$router.push({ name: "exportWorkspace", query: { v: this.token } });
            } catch (error) {
                // Navigation was aborted, likely due to auth guard redirect
            }
        },
        async shareWorkspace(): Promise<void> {
            try {
                await this.$router.push({ name: "shareWorkspace", query: { v: this.token } });
            } catch (error) {
                // Navigation was aborted, likely due to auth guard redirect
            }
        },
        async eventClicked(id: number): Promise<void> {
            if (this.token) {
                await this.$router.push({
                    name: "exploreShortBookmark",
                    query: { v: this.token },
                    hash: `#event-id-${id}`,
                });
            }
        },
    },
});
</script>

<style lang="scss"></style>
