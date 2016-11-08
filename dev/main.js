import Vue from 'vue/dist/vue'
import AppList from './components/AppList.vue'
import $ from 'jquery'

window.Vue = Vue;

$( function () {
    new Vue({
        el: '.app-manager',
        components: {
            appList: AppList
        }
    })
})
