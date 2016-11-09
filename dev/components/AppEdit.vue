<template>
    <div class="wrapper" v-show="ready">
        Installname: <input type="text" v-model="config.destinationWeb"/>
        <button class="button primary" v-on:click="customInstall()">Install</button>
        <button class="button alert" v-on:click="abort()">Abort</button>
    </div>
</template>

<script>
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import $ from 'jquery'

export default {
    props: ['config'],
    data : function () {
       return {
           ready: false
       }
    },
    methods: {
        abort: function () {
            this.$parent.$emit('reload');
        },
        customInstall: function() {
            var requestData = {
                    version: "1",
                    name: this.config.name,
                    action: JSON.stringify(this.config)
            };
            this.request = $.post(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/appaction"
                , requestData)
            .done( function(result) {
                result = JSON.parse(result);
                console.log(result);
                self.infos = result;
                NProgress.done();
            })
            .fail( function(xhr, status, error) {
                window.console && console.log(status + ': '+ error);
                NProgress.done();
            });
        }
    },
    created: function() {
        this.ready = true;
    }
}
</script>

<style lang="sass">
</style>
