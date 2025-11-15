<template>
    <section class="container" v-bind:class="{ 'data-view': viewType === 'data' }">
        <header v-if="viewType === 'project'">{{ $tc("comments.projectHeader") }}</header>

        <SectionToggle
            class="comment-toggle"
            :leftLabel="$tc('comments.sectionToggle.leftLabel')"
            :rightLabel="$tc('comments.sectionToggle.rightLabel')"
            :default="permissions.canAddComment ? 'left' : 'right'"
            :show="{ left: permissions.canAddComment, right: permissions.canAddEvent }"
            @toggle="onSectionToggle"
            v-if="viewType === 'data' && permissions"
        >
            <template #left>
                <div class="new-comment" :class="{ 'align-center': !user }">
                    <UserPhoto :user="user"></UserPhoto>
                    <template v-if="user">
                        <div class="new-comment-wrap">
                            <Tiptap
                                v-model="newComment.body"
                                :placeholder="$tc('comments.commentForm.placeholder')"
                                :saveLabel="$tc('comments.commentForm.saveLabel')"
                                @input="$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, 'newComment')"
                                @empty="$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, 'newComment')"
                                @save="save(newComment, 'newComment')"
                            />
                        </div>
                    </template>
                    <template v-else>
                        <p class="need-login-msg">
                            {{ $tc("comments.loginToComment.part1") }}
                            <router-link
                                :to="{ name: 'login', query: { after: $route.path, params: JSON.stringify($route.query) } }"
                                class="link"
                            >
                                {{ $tc("comments.loginToComment.part2") }}
                            </router-link>
                            {{ $tc("comments.loginToComment.part3") }}
                        </p>
                        <router-link
                            :to="{ name: 'login', query: { after: $route.path, params: JSON.stringify($route.query) } }"
                            class="button-submit"
                        >
                            {{ $t("login.loginButton") }}
                        </router-link>
                    </template>
                </div>
            </template>
            <template #right v-if="permissions.canAddEvent">
                <div class="event-level-selector">
                    <label for="allProjectRadio" v-if="stationBelongsToAProject">
                        <div class="event-level-radio">
                            <input
                                type="radio"
                                id="allProjectRadio"
                                name="eventLevel"
                                v-model="newDataEvent.allProjectSensors"
                                :value="true"
                                :checked="newDataEvent.allProjectSensors"
                            />
                            <span class="radio-label">
                                {{ $tc(interpolatePartner("comments.eventTypeSelector.allProjectSensors.radioLabel.")) }}
                            </span>

                            <InfoTooltip
                                :message="$tc(interpolatePartner('comments.eventTypeSelector.allProjectSensors.description.'))"
                            ></InfoTooltip>

                            <p>
                                {{ $tc(interpolatePartner("comments.eventTypeSelector.allProjectSensors.description.")) }}
                            </p>
                        </div>
                    </label>
                    <label for="allSensorsRadio">
                        <div class="event-level-radio">
                            <input
                                type="radio"
                                id="allSensorsRadio"
                                name="eventLevel"
                                v-model="newDataEvent.allProjectSensors"
                                :value="false"
                                :checked="!newDataEvent.allProjectSensors"
                            />
                            <span class="radio-label">
                                {{ $tc(interpolatePartner("comments.eventTypeSelector.justTheseSensors.radioLabel.")) }}
                            </span>

                            <InfoTooltip
                                :message="$tc(interpolatePartner('comments.eventTypeSelector.justTheseSensors.description.'))"
                            ></InfoTooltip>

                            <p>
                                {{ $tc(interpolatePartner("comments.eventTypeSelector.justTheseSensors.description.")) }}
                            </p>
                        </div>
                    </label>
                </div>
                <div class="new-comment" :class="{ 'align-center': !user }">
                    <UserPhoto :user="user"></UserPhoto>
                    <template v-if="user">
                        <div class="new-comment-wrap">
                            <Tiptap
                                v-model="newDataEvent.title"
                                :placeholder="$tc('comments.eventForm.title.placeholder')"
                                :saveLabel="$tc('comments.eventForm.title.saveLabel')"
                                :showSaveButton="false"
                                @input="$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, 'newDataEventTitle')"
                                @empty="$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, 'newDataEventTitle')"
                                @save="saveDataEvent(newDataEvent)"
                            />
                            <Tiptap
                                v-model="newDataEvent.description"
                                :placeholder="$tc('comments.eventForm.description.placeholder')"
                                :saveLabel="$tc('comments.eventForm.description.saveLabel')"
                                @input="$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, 'newDataEventDesc')"
                                @empty="$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, 'newDataEventDesc')"
                                @save="saveDataEvent(newDataEvent)"
                            />
                        </div>
                    </template>
                    <template v-else>
                        <p class="need-login-msg">
                            {{ $tc("comments.loginToComment.part1") }}
                            <router-link
                                :to="{ name: 'login', query: { after: $route.path, params: JSON.stringify($route.query) } }"
                                class="link"
                            >
                                {{ $tc("comments.loginToComment.part2") }}
                            </router-link>
                            {{ $tc("comments.loginToComment.part3") }}
                        </p>
                        <router-link
                            :to="{ name: 'login', query: { after: $route.path, params: JSON.stringify($route.query) } }"
                            class="button-submit"
                        >
                            {{ $t("login.loginButton") }}
                        </router-link>
                    </template>
                </div>
            </template>
        </SectionToggle>
        <!-- TODO: code repeated for project view; componentize -->
        <div class="new-comment" :class="{ 'align-center': !user }" v-if="viewType === 'project'">
            <UserPhoto :user="user"></UserPhoto>
            <template v-if="user">
                <div class="new-comment-wrap">
                    <Tiptap
                        v-model="newComment.body"
                        :placeholder="$tc('comments.commentForm.placeholder')"
                        :saveLabel="$tc('comments.commentForm.saveLabel')"
                        @input="$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, 'newComment')"
                        @empty="$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, 'newComment')"
                        @save="save(newComment, 'newComment')"
                    />
                </div>
            </template>
            <template v-else>
                <p class="need-login-msg">
                    {{ $tc("comments.loginToComment.part1") }}
                    <router-link :to="{ name: 'login', query: { after: $route.path, params: JSON.stringify($route.query) } }" class="link">
                        {{ $tc("comments.loginToComment.part2") }}
                    </router-link>
                    {{ $tc("comments.loginToComment.part3") }}
                </p>
                <router-link
                    :to="{ name: 'login', query: { after: $route.path, params: JSON.stringify($route.query) } }"
                    class="button-submit"
                >
                    {{ $t("login.loginButton") }}
                </router-link>
            </template>
        </div>

        <div v-if="!isLoading && postsAndEvents.length === 0" class="no-comments">
            {{ viewType === "data" ? $tc("comments.noEventsComments") : $tc("comments.noComments") }}
        </div>
        <div v-if="isLoading" class="no-comments">
            {{ viewType === "data" ? $tc("comments.loadingEventsComments") : $tc("comments.loadingComments") }}
        </div>
        <div class="list" v-if="postsAndEvents && postsAndEvents.length > 0">
            <div class="subheader">
                <span class="comments-counter" v-if="viewType === 'project'">
                    {{ postsAndEvents.length }} {{ $tc("comments.comments") }}
                </span>
                <header v-if="viewType === 'data'">{{ $tc("comments.dataHeader") }}</header>
            </div>
            <transition-group name="fade">
                <div
                    class="comment comment-first-level"
                    v-for="item in postsAndEvents"
                    v-bind:key="(item.type === 'comment' ? 'c' : 'e') + item.id"
                    v-bind:id="(item.body ? 'comment-id-' : 'event-id-') + item.id"
                    :ref="item.id"
                >
                    <div class="comment-main" :style="!user ? { 'padding-bottom': '15px' } : {}">
                        <UserPhoto :user="item.author"></UserPhoto>
                        <div class="column-post">
                            <div class="post-header">
                                <span class="author">
                                    {{ item.author.name }}
                                </span>
                                <span v-if="item.body" class="icon icon-comment"></span>
                                <span v-else class="icon icon-flag"></span>
                                <ListItemOptions
                                    v-if="user"
                                    @listItemOptionClick="onListItemOptionClick($event, item)"
                                    :options="getCommentOptions(item)"
                                    :ref="'options-' + item.id"
                                />
                                <CancelReportLink
                                    v-if="user"
                                    :postId="item.id"
                                    :postType="item.body ? PostType.DISCUSSION_POST : PostType.DATA_EVENT"
                                    :userHasReported="item.userHasReported || false"
                                    @report-canceled="onReportCanceled(item)"
                                    :ref="'cancel-report-' + item.id"
                                />
                                <span class="timestamp">{{ formatTimestamp(item.createdAt) }}</span>
                            </div>
                            <Tiptap
                                v-if="item.body"
                                v-model="item.body"
                                :readonly="item.readonly"
                                :saveLabel="$tc('comments.commentForm.saveEditLabel')"
                                @input="$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, 'editComment#' + item.id)"
                                @empty="$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, 'editComment#' + item.id)"
                                @save="saveEdit(item.id, item.body, 'editComment#' + item.id)"
                            />
                            <div v-else class="edit-event">
                                <Tiptap
                                    v-model="item.title"
                                    :readonly="item.readonly"
                                    :placeholder="$tc('comments.eventForm.title.placeholder')"
                                    :saveLabel="$tc('comments.eventForm.title.saveLabel')"
                                    :showSaveButton="false"
                                    @input="$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, 'editEventTitle#' + item.id)"
                                    @empty="$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, 'editEventTitle#' + item.id)"
                                    @save="saveEditDataEvent(item)"
                                />
                                <div class="event-range">{{ item.start | prettyDateTime }} - {{ item.end | prettyDateTime }}</div>
                                <Tiptap
                                    v-model="item.description"
                                    :readonly="item.readonly"
                                    :placeholder="$tc('comments.eventForm.description.placeholder')"
                                    :saveLabel="$tc('comments.eventForm.description.saveLabel')"
                                    @input="$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, 'editEventDesc#' + item.id)"
                                    @empty="$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, 'editEventDesc#' + item.id)"
                                    @save="saveEditDataEvent(item)"
                                />
                            </div>
                        </div>
                    </div>
                    <div class="column">
                        <transition-group name="fade" class="comment-replies">
                            <div
                                class="comment"
                                v-for="reply in item.replies"
                                v-bind:key="reply.id"
                                v-bind:id="'comment-id-' + reply.id"
                                :ref="reply.id"
                            >
                                <div class="comment-main">
                                    <UserPhoto :user="reply.author"></UserPhoto>
                                    <div class="column-reply">
                                        <div class="post-header">
                                            <span class="author">
                                                {{ reply.author.name }}
                                            </span>
                                            <ListItemOptions
                                                v-if="user"
                                                @listItemOptionClick="onListItemOptionClick($event, reply)"
                                                :options="getCommentOptions(reply)"
                                            />
                                        </div>
                                        <Tiptap
                                            v-model="reply.body"
                                            :readonly="reply.readonly"
                                            :saveLabel="$tc('comments.reply.saveLabel')"
                                            @input="$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, 'editCommentReply#' + reply.id)"
                                            @empty="$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, 'editCommentReply#' + reply.id)"
                                            @save="saveEdit(reply.id, reply.body, 'editCommentReply#' + reply.id)"
                                        />
                                    </div>
                                </div>
                            </div>
                        </transition-group>

                        <transition name="fade">
                            <div class="new-comment reply" v-if="newReply && newReply.threadId === item.id">
                                <div class="new-comment-wrap">
                                    <UserPhoto :user="user"></UserPhoto>
                                    <Tiptap
                                        v-model="newReply.body"
                                        :placeholder="$tc('comments.reply.placeholder')"
                                        :saveLabel="$tc('comments.reply.saveLabel')"
                                        @input="$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, 'newCommentReply')"
                                        @empty="$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, 'newCommentReply')"
                                        @save="save(newReply, 'newCommentReply')"
                                    />
                                </div>
                            </div>
                        </transition>

                        <div class="actions">
                            <button v-if="user && item.body" @click="addReply(item)">
                                <i class="icon icon-reply"></i>
                                {{ $t("comments.actions.reply") }}
                            </button>
                            <button v-if="viewType === 'data'" @click="viewDataClick(item)">
                                <i class="icon icon-view-data"></i>
                                {{ $t("comments.actions.viewData") }}
                            </button>
                        </div>
                    </div>
                </div>
            </transition-group>
        </div>
    </section>
</template>

<script lang="ts">
import _ from "lodash";
import Vue, { PropType } from "vue";
import CommonComponents from "@/views/shared";
import moment from "moment";
import { NewComment, NewDataEvent } from "@/views/comments/model";
import { Comment, DataEvent, DiscussionBase } from "@/views/comments/model";
import { CurrentUser, ProjectUser, PostType } from "@/api";
import ListItemOptions from "@/views/shared/ListItemOptions.vue";
import Tiptap from "@/views/shared/Tiptap.vue";
import { deserializeBookmark, Workspace } from "../viz/viz";
import SectionToggle from "@/views/shared/SectionToggle.vue";
import { Bookmark } from "@/views/viz/viz";
import { TimeRange } from "@/views/viz/common";
import { ActionTypes } from "@/store";
import { interpolatePartner } from "@/views/shared/partners";
import InfoTooltip from "@/views/shared/InfoTooltip.vue";
import { SnackbarStyle } from "@/store/modules/snackbar";
import CancelReportLink from "@/views/shared/CancelReportLink.vue";

export default Vue.extend({
    name: "Comments",
    components: {
        ...CommonComponents,
        ListItemOptions,
        Tiptap,
        SectionToggle,
        InfoTooltip,
        CancelReportLink,
    },
    props: {
        user: {
            type: Object as PropType<CurrentUser>,
            required: false,
        },
        parentData: {
            type: [Object, Number],
            required: true,
        },
        workspace: {
            type: Workspace,
            required: false,
        },
    },
    data(): {
        posts: Comment[];
        dataEvents: DataEvent[];
        isLoading: boolean;
        placeholder: string | null;
        viewType: string;
        newComment: {
            projectId: number | null;
            bookmark: string | null;
            body: string | null;
        };
        newReply: {
            projectId: number | null;
            bookmark: string | null;
            body: string | null;
            threadId: number | null;
        };
        newDataEvent: {
            allProjectSensors: boolean;
            bookmark: string | null;
            description: string | null;
            title: string | null;
        };
        logMode: string;
    } {
        return {
            posts: [],
            dataEvents: [],
            isLoading: true,
            placeholder: null,
            viewType: typeof this.$props.parentData === "number" ? "project" : "data",
            newComment: {
                projectId: typeof this.parentData === "number" ? this.parentData : null,
                bookmark: null,
                body: "",
            },
            newReply: {
                projectId: typeof this.parentData === "number" ? this.parentData : null,
                bookmark: null,
                body: "",
                threadId: null,
            },
            newDataEvent: {
                allProjectSensors: true,
                bookmark: null,
                description: "",
                title: "",
            },
            logMode: "comment",
        };
    },
    computed: {
        ActionTypes() {
            return ActionTypes;
        },
        PostType() {
            return PostType;
        },
        projectId(): number {
            if (this.parentData instanceof Bookmark) {
                return this.parentData.p[0];
            }
            return this.parentData;
        },
        stationId(): number | null {
            if (this.parentData instanceof Bookmark) {
                return this.parentData.s[0];
            }
            return null;
        },
        // we need it in order to see if the user is an admin and can delete posts
        isAdmin(): boolean {
            if (this.user.id && this.projectId) {
                return this.$store.getters.isAdminForProject(this.user.id, this.projectId);
            }
            return false;
        },
        isProjectLoaded(): boolean {
            if (this.projectId) {
                const project = this.$getters.projectsById[this.projectId];
                if (!project) {
                    this.$store.dispatch(ActionTypes.NEED_PROJECT, { id: this.projectId });
                }
                return !!this.$getters.projectsById[this.projectId];
            }
            return false;
        },
        dataEventsFromState(): DataEvent[] {
            return this.$state.discussion.dataEvents;
        },
        postsAndEvents(): DiscussionBase[] {
            return [...this.posts, ...this.dataEvents].sort(this.sortRecent);
        },
        projectUser(): ProjectUser | null {
            const projectId = this.parentData instanceof Bookmark ? this.parentData.p[0] : null;

            if (projectId) {
                const displayProject = this.$getters.projectsById[projectId];
                return displayProject?.users?.filter((user) => user.user.id === this.user?.id)[0];
            }

            return null;
        },
        stationBelongsToAProject(): boolean {
            if (this.parentData instanceof Bookmark) {
                return !!this.parentData.p?.length;
            }
            return false;
        },
        parentNumber(): number | null {
            if (_.isNumber(this.parentData)) {
                return this.parentData;
            }
            return null;
        },
        parentBookmark(): Bookmark | null {
            if (this.parentData instanceof Bookmark) {
                return this.parentData;
            }
            return null;
        },
        permissions(): { canAddComment: boolean; canAddEvent: boolean } {
            return this.$state.discussion.permissions;
        },
    },
    watch: {
        async parentData(): Promise<void> {
            await this.getDataEvents();
            return this.getComments();
        },
        async $route(): Promise<void> {
            await this.getComments();
            this.highlightComment();
        },
        dataEventsFromState(): void {
            this.initDataEvents();
        },
    },
    async mounted(): Promise<void> {
        const projectId = this.parentData instanceof Bookmark ? this.parentData.p[0] : null;

        if (projectId) {
            await this.$store.dispatch(ActionTypes.NEED_PROJECT, { id: projectId });
            await this.$getters.projectsById[projectId];
        }
        this.placeholder = this.getNewCommentPlaceholder();
        this.newDataEvent.allProjectSensors = this.stationBelongsToAProject;

        await this.getDataEvents();
        return this.getComments();
    },
    methods: {
        getNewCommentPlaceholder(): string {
            if (this.viewType === "project") {
                return "Comment on Project";
            } else {
                return "Write a comment about this Data View";
            }
        },
        async saveDataEvent(dataEvent: NewDataEvent): Promise<void> {
            const bookmark = this.parentBookmark;
            if (bookmark != null) {
                if (this.viewType === "data") {
                    dataEvent.bookmark = JSON.stringify(bookmark);
                }

                const timeRange: TimeRange = bookmark.allTimeRange;
                dataEvent.start = timeRange.start;
                dataEvent.end = timeRange.end;
            }

            await this.$services.api
                .postDataEvent(dataEvent)
                .then((response) => {
                    if (response) {
                        this.newDataEvent.title = "";
                        this.newDataEvent.description = "";

                        this.getDataEvents();
                        this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                            message: this.$tc("comments.dataEventSuccess"),
                            type: SnackbarStyle.success,
                        });
                        this.$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, "newDataEventTitle");
                        this.$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, "newDataEventDesc");
                    }
                })
                .catch((e) => {
                    console.error(e);
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("somethingWentWrong"),
                        type: SnackbarStyle.fail,
                    });
                });
        },
        async save(comment: NewComment, dirtyInputId: string): Promise<void> {
            if (this.viewType === "data") {
                comment.bookmark = JSON.stringify(this.parentData);
            }

            await this.$services.api
                .postComment(comment)
                .then((response: { post: Comment }) => {
                    this.$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, dirtyInputId);
                    // add the comment to the replies array
                    if (comment.threadId) {
                        if (this.posts) {
                            this.posts
                                .filter((post) => post.id === comment.threadId)[0]
                                .replies.push(
                                    new Comment(
                                        response.post.id,
                                        response.post.author,
                                        response.post.bookmark,
                                        response.post.body,
                                        response.post.createdAt,
                                        response.post.updatedAt,
                                        response.post.userHasReported
                                    )
                                );
                            this.resetNewReply();
                        } else {
                            console.warn(`posts is null`);
                        }
                    } else {
                        // add it to the posts array
                        if (this.posts) {
                            this.posts.unshift(
                                new Comment(
                                    response.post.id,
                                    response.post.author,
                                    response.post.bookmark,
                                    response.post.body,
                                    response.post.createdAt,
                                    response.post.updatedAt,
                                    response.post.userHasReported
                                )
                            );
                            this.newComment.body = "";
                        } else {
                            console.log(`posts is null`);
                        }
                    }
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("comments.saveSuccess"),
                        type: SnackbarStyle.success,
                    });
                })
                .catch((e) => {
                    console.log("e", e);
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("somethingWentWrong"),
                        type: SnackbarStyle.fail,
                    });
                });
        },
        formatTimestamp(timestamp: number): string {
            return moment(timestamp).fromNow();
        },
        addReply(post: Comment): void {
            if (this.newReply.body && post.id === this.newReply.threadId) {
                return;
            }
            this.newReply.threadId = post.id;
            this.newReply.body = "";
        },
        async getComments(): Promise<void> {
            const queryParam = this.parentNumber ? this.parentNumber : this.parentBookmark;
            if (!queryParam) {
                return;
            }
            this.isLoading = true;
            await this.$services.api
                .getComments(queryParam)
                .then((data) => {
                    this.posts = [];
                    data.posts.forEach((post) => {
                        this.posts.push(
                            new Comment(
                                post.id,
                                post.author,
                                post.bookmark,
                                post.body,
                                post.createdAt,
                                post.updatedAt,
                                post.userHasReported
                            )
                        );

                        post.replies.forEach((reply) => {
                            this.posts[this.posts.length - 1].replies.push(
                                new Comment(
                                    reply.id,
                                    reply.author,
                                    reply.bookmark,
                                    reply.body,
                                    reply.createdAt,
                                    reply.updatedAt,
                                    reply.userHasReported
                                )
                            );
                        });
                    });

                    this.highlightComment();
                })
                .catch(() => {
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("somethingWentWrong"),
                        type: SnackbarStyle.fail,
                    });
                })
                .finally(() => {
                    this.isLoading = false;
                });
        },
        viewDataClick(post: Comment) {
            if (post.bookmark) {
                this.$emit("viewDataClicked", deserializeBookmark(post.bookmark));
                window.scrollTo({ top: 0, left: 0, behavior: "smooth" });
            }
        },
        deleteComment(commentID: number) {
            this.$services.api
                .deleteComment(commentID)
                .then((response) => {
                    if (response) {
                        this.getComments();
                        this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                            message: this.$tc("comments.deleteSuccess"),
                            type: SnackbarStyle.success,
                        });
                    } else {
                        this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                            message: this.$tc("somethingWentWrong"),
                            type: SnackbarStyle.fail,
                        });
                    }
                })
                .catch(() => {
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("somethingWentWrong"),
                        type: SnackbarStyle.fail,
                    });
                });
        },
        startEditing(item: Comment | DataEvent): void {
            item.readonly = false;
        },
        saveEdit(commentID: number, body: Record<string, unknown>, dirtyInputId: string) {
            this.$services.api
                .editComment(commentID, body)
                .then((response) => {
                    if (response) {
                        this.$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, dirtyInputId);
                        this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                            message: this.$tc("comments.saveSuccess"),
                            type: SnackbarStyle.success,
                        });
                        this.getComments();
                    } else {
                        this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                            message: this.$tc("somethingWentWrong"),
                            type: SnackbarStyle.fail,
                        });
                    }
                })
                .catch(() => {
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("somethingWentWrong"),
                        type: SnackbarStyle.fail,
                    });
                });
        },
        async getDataEvents(): Promise<void> {
            if (typeof this.parentData === "number") {
                this.dataEvents = [];
                return;
            }
            this.isLoading = true;
            await this.$store
                .dispatch(ActionTypes.NEED_DATA_EVENTS, { bookmark: JSON.stringify(this.parentData) })
                .catch(() => {
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("somethingWentWrong"),
                        type: SnackbarStyle.fail,
                    });
                })
                .finally(() => {
                    this.isLoading = false;
                });
        },
        initDataEvents(): void {
            this.dataEvents = [];
            this.dataEventsFromState.forEach((event) => {
                this.dataEvents.push(
                    new DataEvent(
                        event.id,
                        event.author,
                        event.bookmark,
                        event.createdAt,
                        event.updatedAt,
                        event.title ? JSON.parse(event.title) : event.title,
                        event.description ? JSON.parse(event.description) : event.description,
                        event.start,
                        event.end,
                        event.userHasReported
                    )
                );
            });
        },
        saveEditDataEvent(dataEvent: DataEvent): Promise<void> {
            return this.$services.api
                .updateDataEvent(dataEvent)
                .then((response) => {
                    if (response) {
                        this.newDataEvent.title = "";
                        this.newDataEvent.description = "";
                        this.$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, "editEventDesc#" + dataEvent.id);
                        this.getDataEvents();
                        this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                            message: this.$tc("comments.dataEventSuccess"),
                            type: SnackbarStyle.success,
                        });
                    }
                })
                .catch((e) => {
                    console.error(e);
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("somethingWentWrong"),
                        type: SnackbarStyle.fail,
                    });
                });
        },
        deleteDataEvent(dataEventID: number): Promise<void> {
            return this.$services.api
                .deleteDataEvent(dataEventID)
                .then((response) => {
                    if (response) {
                        this.getDataEvents();
                        this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                            message: this.$tc("comments.dataEventDeleteSuccess"),
                            type: SnackbarStyle.success,
                        });
                    } else {
                        this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                            message: this.$tc("somethingWentWrong"),
                            type: SnackbarStyle.fail,
                        });
                    }
                })
                .catch(() => {
                    this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                        message: this.$tc("somethingWentWrong"),
                        type: SnackbarStyle.fail,
                    });
                });
        },
        onListItemOptionClick(event: string, item: Comment | DataEvent): void {
            if (event === "edit-comment") {
                this.startEditing(item);
            }
            if (event === "delete-comment") {
                if (item.type === "comment") {
                    this.deleteComment(item.id);
                }
                if (item.type === "event") {
                    this.deleteDataEvent(item.id);
                }
            }
            if (event === "report") {
                this.$services.api
                    .reportPost(item)
                    .then(() => {
                        this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                            message: this.$tc("comments.reportSuccess"),
                            type: SnackbarStyle.success,
                        });
                        item.userHasReported = true;
                        this.closeOptionsMenu(item.id);
                    })
                    .catch(() => {
                        this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                            message: this.$tc("comments.reportError"),
                            type: SnackbarStyle.fail,
                        });
                        this.closeOptionsMenu(item.id);
                    });
            }
        },
        getCommentOptions(post: Comment): { label: string; event: string }[] {
            if (!this.user) {
                return [];
            }

            const options: { label: string; event: string }[] = [];

            if (this.user.id === post.author.id) {
                options.push({ label: "Edit post", event: "edit-comment" }, { label: "Delete post", event: "delete-comment" });
            }

            if (this.user.id !== post.author.id) {
                options.push({ label: "Report", event: "report" });
            }

            return options;
        },
        highlightComment(): void {
            this.$nextTick(() => {
                if (location.hash) {
                    const el = document.querySelector(location.hash);

                    if (el) {
                        el.scrollIntoView({ behavior: "smooth", block: "center" });
                        el.classList.add("highlight");
                        setTimeout(() => {
                            el.classList.remove("highlight");
                        }, 5000);
                    }
                }
            });
        },
        onSectionToggle(evt): void {
            if (evt === "left") {
                this.logMode = "comment";
            }
            if (evt === "right") {
                this.logMode = "event";
            }
        },
        sortRecent(a, b): any {
            return b.createdAt - a.createdAt;
        },
        interpolatePartner(baseString): string {
            return interpolatePartner(baseString);
        },
        onEditCommentInput(comment: any, event: string) {
            if (JSON.stringify(event) !== comment.body) {
                this.$store.dispatch(ActionTypes.NEW_DIRTY_FIELD, "editComment#" + comment.id);
            } else {
                this.$store.dispatch(ActionTypes.CLEAR_DIRTY_FIELD, "editComment#" + comment.id);
            }
        },
        resetNewReply() {
            this.newReply = {
                ...this.newReply,
                body: null,
                threadId: null,
            };
        },
        onReportCanceled(item: any) {
            if (item) {
                item.userHasReported = false;
            }
        },
        closeOptionsMenu(id: number) {
            const optionsRef = this.$refs["options-" + id];
            if (Array.isArray(optionsRef) && optionsRef[0] && "querySelector" in (optionsRef[0] as Vue).$el) {
                const menuEl = ((optionsRef[0] as Vue).$el as HTMLElement).querySelector(".options-btns");
                if (menuEl) {
                    menuEl.classList.remove("visible");
                }
            }
        },
    },
});
</script>

<style lang="scss" scoped>
@use "src/scss/global";
@use "src/scss/mixins";
@use "src/scss/variables";

button {
    padding: 0;
    border: 0;
    outline: 0;
    box-shadow: none;
    cursor: pointer;
    background: transparent;
}

* {
    box-sizing: border-box;
    font-size: 14px;
}

.hide {
    display: none;
}

.container {
    margin-top: 20px;
    padding: 0 0 30px 0;
    background: #fff;
    border-radius: 1px;
    border: 1px solid variables.$color-border;
    box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.05);

    @include mixins.bp-down(variables.$xs) {
        margin: 20px -10px 0;
        padding: 0 0 30px 0;
    }

    &.data-view {
        margin-top: 0;
        // padding-top: 45px;
        box-shadow: none;
        border: 0;
    }
}

header {
    @include mixins.flex(center, space-between);
    padding: 13px 20px;
    border-bottom: 1px solid variables.$color-border;
    font-size: 20px;
    font-weight: 500;

    @include mixins.bp-down(variables.$xs) {
        padding: 13px 10px;
    }

    .data-view & {
        font-size: 18px;
        height: auto;
        border: none;
    }

    body.floodnet & {
        font-family: variables.$font-family-floodnet-bold;
    }
}

.subheader {
    @include mixins.flex(center, space-between);
    border-top: 1px solid variables.$color-border;
    border-bottom: 1px solid variables.$color-border;
    padding: 15px 20px;

    @include mixins.bp-down(variables.$xs) {
        padding: 15px 10px;
    }

    .data-view & {
        border-top: none;
        padding: 0;
    }
}

.list {
    overflow: hidden;

    .data-view & {
        margin-top: 30px;
        @include mixins.bp-down(variables.$xs) {
            margin-top: 10px;
        }
    }
}

::v-deep .new-comment {
    @include mixins.flex(flex-start);
    padding: 22px 20px;
    position: relative;
    margin-left: 20px;
    margin-right: 20px;

    @include mixins.bp-down(variables.$xs) {
        margin: 0 -10px;
        padding: 15px 10px;
    }

    @media screen and (max-width: 320px) {
        flex-wrap: wrap;
    }

    .container.data-view & {
        &:not(.reply) {
            background-color: rgba(#f4f5f7, 0.55);
            padding: 18px 23px 17px 15px;
        }
    }

    &.reply {
        padding: 0 0 0;
        margin: 10px 0 0 0;
        width: 100%;
    }

    &.align-center {
        align-items: center;
    }

    img {
        margin-top: 0 !important;
        width: 30px;
        height: 30px;
    }

    .button-submit {
        margin-left: auto;

        @media screen and (max-width: 320px) {
            width: 100%;
        }
    }

    &:not(.reply) {
        img {
            width: 46px;
            height: 46px;

            @include mixins.bp-down(variables.$xs) {
                width: 42px;
                height: 42px;
            }
        }

        .new-comment-wrap {
            flex: 0 0 calc(100% - 65px);
            flex-direction: column;
            background-color: rgba(#f4f5f7, 0.55);

            .tiptap-container {
                background-color: white;

                &:nth-of-type(2) {
                    margin-top: 10px;
                }
            }
        }
    }

    &-wrap {
        display: flex;
        width: 100%;
        position: relative;
        background-color: #fff;
    }
}
// .ProseMirror p.is-editor-empty:first-child::before {
// 	color: #adb5bd;
// 	content: attr(data-placeholder);
// 	float: left;
// 	height: 0;
// 	pointer-events: none;
// }

.comments-counter {
    font-family: variables.$font-family-light;
}

.author {
    font-size: 16px;
    font-weight: 500;
    position: relative;
}

.body {
    max-width: unset;
    font-family: variables.$font-family-light;
    outline: none;
    border: solid 1px variables.$color-border;
    width: calc(100% - 40px);
    overflow-wrap: break-word;

    &[readonly] {
        border: none;
        max-width: 550px;
        min-height: unset;
    }
}

.comment {
    @include mixins.flex(flex-start);
    flex: 100%;
    padding: 15px 20px 0 20px;
    position: relative;
    flex-wrap: wrap;

    @include mixins.bp-down(variables.$xs) {
        padding: 15px 10px 0 10px;
        scroll-margin-top: 50px;
    }

    &-first-level {
        border-bottom: 1px solid variables.$color-border;
    }

    &::v-deep .default-user-icon {
        margin-top: 0;
        width: 30px;
        height: 30px;
    }

    .column {
        &:nth-of-type(2) {
            padding-left: 36px;
        }
    }

    &.highlight {
        background-color: #f5fbfc;
    }
}

.comment-replies {
    width: 100%;

    .column {
        border-bottom: none;
    }
}

.comment-main {
    display: flex;
    flex: 100%;
    overflow-wrap: break-word;
}

.column {
    @include mixins.flex(flex-start);
    width: 100%;
    flex-direction: column;
    position: relative;

    > * {
        overflow-wrap: anywhere;
    }
}

.actions {
    margin: 15px 0;
    user-select: none;
    @include mixins.flex();

    button {
        font-weight: 500;
        margin-right: 20px;
        @include mixins.flex(center);
    }

    .icon {
        font-size: 11px;
        margin-right: 5px;
    }

    .icon-view-data {
        font-size: 14px;
        margin-right: 6px;
    }

    .icon-reply {
        margin-top: -2px;
    }
}

.timestamp {
    font-family: variables.$font-family-light;
    flex-shrink: 0;
    margin-left: auto;
    line-height: 1.5;
    padding-left: 10px;
}

.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.25s ease-in-out;
}

.column-reply,
.column-post {
    position: relative;
    display: flex;
    flex-direction: column;
    width: 100%;
}

.post-header {
    display: flex;
    align-items: center;
    margin-bottom: 5px;

    .icon {
        font-size: 12px;
        margin-left: 5px;

        @include mixins.bp-up(variables.$md) {
            margin-top: -2px;
        }
    }
}

.need-login-msg {
    font-size: 16px;
    margin-left: 8px;
    margin-right: 10px;

    @include mixins.bp-down(variables.$xs) {
        margin-left: 0;
    }

    @media screen and (max-width: 320px) {
        flex: 0 0 calc(100% - 55px);
        margin-right: 0;
    }

    * {
        font-size: 16px;
    }
}

.button-submit {
    width: auto;
    margin-left: auto;
    padding: 0 40px;
}

.no-comments {
    margin-left: 20px;

    @at-root .data-view .no-comments {
        margin-top: 5px;
    }

    @include mixins.bp-down(variables.$xs) {
        margin-left: 10px;
    }
}
.event-level-selector {
    display: flex;
    flex-direction: row;
    align-items: stretch;
    justify-content: center;
    margin-bottom: 15px;

    .info {
        display: none;
    }

    @include mixins.bp-down(variables.$xs) {
        flex-direction: column;

        label {
            width: 100%;
        }

        .info {
            display: inline-block;
            float: right;
        }

        ::v-deep .info-content {
            right: 0;
        }
    }
}
.event-level-radio {
    width: 340px;
    min-height: 115px;
    height: 100%;
    border: solid 1px #d8dce0;
    padding: 15px;
    padding-bottom: 10px;
    margin-left: 10px;
    border-radius: 3px;
    flex: 1;

    @include mixins.bp-down(variables.$xs) {
        width: calc(100% - 20px);
        height: auto;
        margin-right: 10px;
        margin-bottom: 5px;
    }

    p {
        margin-left: 30px;

        @include mixins.bp-down(variables.$xs) {
            display: none;
        }
    }

    .radio-label {
        color: #2c3e50;
        font-size: 18px;
        font-weight: 900;
        margin-left: 10px;
    }
    input:checked {
        background-color: red;
    }
}

.event-sensor-radio > input:checked + div {
    /* (RADIO CHECKED) DIV STYLES */
    background-color: #ffd6bb;
    border: 1px solid #ff6600;
}
.comment-toggle {
    margin-top: 22px;
}

.edit-event {
    > * {
        margin-top: 10px;
    }

    .tiptap-container:first-child {
        font-weight: bold;
    }
}

.event-range {
    margin-top: 0px;
    font-size: 12px;
}

.icon-flag,
.icon-comment,
.icon-view-data {
    &::before {
        body.floodnet & {
            color: variables.$color-floodnet-dark;
        }
    }
}
</style>
