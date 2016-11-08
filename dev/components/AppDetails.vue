<template>
    <div class="wrapper">
        <div class="widgetBlockTitle">
        {{ app }}
        </div>
        <div class="widgetBlockContent">
            test!
            TEt!
        </div>
    </div>
</template>

<script>
import NProgress from 'nprogress'
import 'nprogress/nprogress.css'
import $ from 'jquery'

export default {
    props: ['app'],
    data : function () {
       return {
           infos: ''
       }
    },
    created: function() {
        self = this;
        this.request = $.get(foswiki.preferences.SCRIPTURL + "/rest/AppManagerPlugin/appdetails?app=" + this.app)
        .done( function(result) {
            result = JSON.parse(result);
            console.log(result);
            self.infos = result;
        })
        .fail( function(xhr, status, error) {
            alert("Error get Data!");
        })
    }
}
</script>

<style lang="sass">
</style>
