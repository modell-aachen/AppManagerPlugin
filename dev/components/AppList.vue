<template>
    <div class="flatskin-wrapped">
        <div class="row">
            <div class="column">
                <ul>
                    <li v-for="app in apps" v-on:click="getDetails(app.name)">
                        <a href="#">{{ app.name }}</a>
                    </li>
                </ul>
            </div>
            <div class="column">
                <app-details v-if="details" :app="appDetails"></app-details>
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
           apps: []
       }
    },
    methods: {
        getDetails: function(name) {
            this.appDetails = name;
            this.details = true;
        }
    },
    created: function() {
        NProgress.start();
        self = this;
        this.request = $.get(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/applist")
        .done( function(result) {
            result = JSON.parse(result);
            console.log(result);
            self.apps = result;
        })
        .fail( function(xhr, status, error) {
            alert("Error get Data!");
        })
        NProgress.done();
    }
}
</script>

<style lang="sass">

</style>
