// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require rails-ujs
//= require activestorage
//= require turbolinks
//= require pagy
//= require all
//= require jquery/dist/jquery.js
//= require leaflet/dist/leaflet.js
//= require leaflet.markercluster/dist/leaflet.markercluster.js
//= require leaflet.locatecontrol/dist/L.Control.Locate.min.js
//= require chartkick
//= require Chart.bundle
//= require jszip
//= require pdfmake
//= require datatables
//= require dataTables.buttons
//= require_tree .

window.addEventListener("turbolinks:load", Pagy.init);

