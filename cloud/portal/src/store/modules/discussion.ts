import Vue from "vue";
import { Services } from "@/api";
import * as ActionTypes from "@/store/actions";
import * as MutationTypes from "@/store/mutations";
import { DataEvent } from "@/views/comments/model";

export class DiscussionState {
    dataEvents: DataEvent[];
    permissions: { canAddComment: boolean; canAddEvent: boolean };
}

const getters = {
    dataEvents(state: DiscussionState): DataEvent[] {
        return state.dataEvents;
    },
};

const actions = (services: Services) => {
    return {
        [ActionTypes.NEED_DATA_EVENTS]: async (
            { commit, dispatch: _dispatch, state: _state }: { commit: any; dispatch: any; state: DiscussionState },
            payload: { bookmark: string }
        ) => {
            const dataEvents = await services.api.getDataEvents(payload.bookmark);
            commit(MutationTypes.DATA_EVENTS_UPDATE, dataEvents);
        },
        [ActionTypes.NEW_DATA_EVENT]: async (
            { commit, dispatch: _dispatch, state: _state }: { commit: any; dispatch: any; state: DiscussionState },
            payload: { dataEvent: DataEvent }
        ) => {
            commit(MutationTypes.DATA_EVENT_APPEND, payload.dataEvent);
        },
        [ActionTypes.SET_DISCUSSION_PERMISSIONS]: async (
            { commit, dispatch, state }: { commit: any; dispatch: any; state: DiscussionState },
            payload: { canAddComment: boolean; canAddEvent: boolean }
        ) => {
            commit(MutationTypes.UPDATE_DISCUSSION_PERMISSIONS, payload);
        },
    };
};

const mutations = {
    [MutationTypes.DATA_EVENTS_UPDATE]: (
        state: DiscussionState,
        payload: {
            events;
        }
    ) => {
        Vue.set(state, "dataEvents", payload.events);
    },
    [MutationTypes.DATA_EVENT_APPEND]: (state: DiscussionState, dataEvent: DataEvent) => {
        state.dataEvents.push(dataEvent);
    },
    [MutationTypes.UPDATE_DISCUSSION_PERMISSIONS]: (
        state: DiscussionState,
        permissions: { canAddComment: boolean; canAddEvent: boolean }
    ) => {
        state.permissions = permissions;
    },
};

export const dataEvents = (services: Services) => {
    const state = () => new DiscussionState();

    return {
        namespaced: false,
        state,
        getters,
        actions: actions(services),
        mutations,
    };
};
