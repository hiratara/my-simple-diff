$(function ($) {
    function submitForm ($form) {
        $.ajax({
            url: $form.attr("action"),
            type: $form.attr("method"),
            data: $form.serialize(),
            timeout: 10000,
            success: function(result, textStatus, xhr) {
                $("#display-result").html(result);
            },
            error: function(xhr, textStatus, error) {
                alert("some error detected. status=" + textStatus + ", error=" + error);
            }
        });
    }

    $("#main_from").change(function () {
        submitForm($(this));
    });
    $("#main_from").submit(function (event) {
        event.preventDefault();
        submitForm($(this));
    });
    $("#main_from").bind("reset", function (event) {
        $("#display-result").html("");
    });
});
