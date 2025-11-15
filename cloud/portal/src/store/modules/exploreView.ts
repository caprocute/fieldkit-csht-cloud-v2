import * as ActionTypes from "@/store/actions";
import * as MutationTypes from "@/store/mutations";

export class ExploreViewState {
    refreshLineChartFn: () => void;
}

const getters = {};

const actions = () => {
    return {
        [ActionTypes.SET_REFRESH_WORKSPACE_FN]: (
            { commit, dispatch: _dispatch, state: _state }: { commit: any; dispatch: any; state: ExploreViewState },
            fn: () => void
        ) => {
            commit(MutationTypes.SET_REFRESH_WORKSPACE_FN, fn);
        },
        [ActionTypes.REFRESH_WORKSPACE]: ({
            commit: _commit,
            dispatch: _dispatch,
            state,
        }: {
            commit: any;
            dispatch: any;
            state: ExploreViewState;
        }) => {
            if (state.refreshLineChartFn) {
                state.refreshLineChartFn();
            }
        },
    };
};

const mutations = {
    [MutationTypes.SET_REFRESH_WORKSPACE_FN]: (state: ExploreViewState, fn: () => void) => {
        state.refreshLineChartFn = fn;
    },
};

export const exploreView = () => {
    const state = () => new ExploreViewState();

    return {
        namespaced: false,
        state,
        getters,
        actions: actions(),
        mutations,
    };
};
