(function () {

    var INACTIVE_CLASS = 'is-inactive';
    var toggles = document.querySelectorAll('nav .slds-grid h4');

    function toggleNavigation(h4_title) {
        var ul_list = h4_title.nextElementSibling;
        if (h4_title.classList.contains(INACTIVE_CLASS)) {
            h4_title.classList.remove(INACTIVE_CLASS);
            ul_list.style.display = "block";
        } else {
            ul_list.style.display = "none";
            h4_title.classList.add(INACTIVE_CLASS);
        }
    }

    Array.prototype.forEach.call(
        toggles,
        /**
         * @param {HTMLElement} toggle
         */
        function (toggle) {
            toggle.addEventListener('click', function (e) { toggleNavigation(e.target); });
            toggleNavigation(toggle);
        }
    )

})();
