% Copyright (c) Facebook, Inc. and its affiliates.
%
% This source code is licensed under the MIT license found in the
% LICENSE file in the root directory of this source tree.

-module(nonmatch_strings).

-export([
    test_match1_Ok/0,
    fn_test_match2_Bad/0,
    fn_test_match3_Bad/0,
    test_match4_Ok/0,
    fn_test_match5_Bad/0,
    fn_test_match6_Bad/0
]).

% TODO: model strings properly T93361792
fp_matches_rabbit("rabbit") -> ok.

test_match1_Ok() -> fp_matches_rabbit("rabbit").

fn_test_match2_Bad() -> fp_matches_rabbit("not a rabbit").

fn_test_match3_Bad() -> fp_matches_rabbit(rabbit).

fp_matches_rabbit_concat("rab" ++ "bit") -> ok.

test_match4_Ok() -> fp_matches_rabbit_concat("rabbit").

fn_test_match5_Bad() -> fp_matches_rabbit_concat("not a rabbit").

fn_test_match6_Bad() -> fp_matches_rabbit_concat(rabbit).
