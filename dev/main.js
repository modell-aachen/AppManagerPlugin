/* global $ Vue */
import AppList from './components/AppList.vue'

$( function () {
    new Vue({
        el: '.app-manager',
        components: {
            appList: AppList
        }
    })
})
