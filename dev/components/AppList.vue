<template>
    <div class="flatskin-wrapped">
        <div class="row expanded">
            <div class="shrink column">
            <table class="ma-table .striped">
                <tr v-for="app in apps" v-on:click="getDetails(app.id)">
                    <td>
                        <a href="#">{{ app.name }}</a>
                    </td>
                </tr>
            </table>
            </div>
            <div class="column">
                <app-details v-if="details" :app="appDetails"></app-details>
            </div>
        </div>
        <div v-if="multisite.available" class="wrapper">
            <div class="cmtBoxTitle">
                <template v-if="!multisite.enabled">
                    Multisite is not enabled: <button class="button primary" v-on:click="toggleMultisite()">enable</button>
                </template>
                <template v-else>
                    Multisite is enabled: <button class="button alert" v-on:click="toggleMultisite()">disable</button>
                </template>
            </div>
        </div>
    </div>
</template>

<script>
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import $ from 'jquery'
import AppDetails from './AppDetails.vue'

export default {
    components: {
        AppDetails
    },
    data : function () {
       return {
           details: false,
           appDetails: '',
           multisite: '',
           apps: []
       }
    },
    methods: {
        getAppList: function() {
            NProgress.start();
            var self = this;
            this.request = $.get(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/applist")
            .done( function(result) {
                result = JSON.parse(result);
                self.apps = result.apps;
                self.multisite = result.multisite;
                NProgress.done();
            })
            .fail( function(xhr, status, error) {
                NProgress.done();
            });
        },
        getDetails: function(id) {
            this.appDetails = id;
            this.details = true;
        },
        toggleMultisite: function() {
            NProgress.start();
            var requestData = {
                enable: !this.multisite.enabled,
            };
            var self = this;
            $.post(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/multisite", requestData)
            .done( function(result) {
                result = JSON.parse(result);
                if(!self.multisite.enabled) {
                    var state = "Activate";
                }else{
                    var state = "Deactivate";
                }
                if(result.success) {
                    swal("Success!",
                    state + " Multisite ",
                    "success");
                } else {
                    swal(state + " Multisite failed!", result.message, "error");
                }
                NProgress.done();
                self.getAppList();
            })
            .fail( function(xhr, status, error) {
                NProgress.done();
            });
        }
    },
    created: function() {
        $( document ).ajaxError(function( event, request, settings, thrownError ) {
                window.console && console.log(request);
                window.console && console.log(settings);
                window.console && console.log(thrownError);
                swal("Request failed!", thrownError, "error");
        });
        NProgress.configure({ showSpinner: false });
        this.getAppList();
    }
}
</script>

<style lang="sass">
.sweet-alert {
    h2 {
        border-style: none;
    }
    hr {
        background-color: transparent;
    }
}
    div .right {
        float: right;
    }
</style>
