final: prev: {
  # font-manager 0.9.4 calls Gtk.DragIcon.get_for_drag() as a static method, but
  # the current gtk4 vapi binds it as a creation method, so valac fails with
  # "use `new' operator to create new objects". Rewrite the two call sites until
  # nixpkgs picks up a fixed font-manager release.
  font-manager = prev.font-manager.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace src/font-manager/Collections.vala src/font-manager/FontList.vala \
          --replace-fail "(Gtk.DragIcon) Gtk.DragIcon.get_for_drag(drag)" "new Gtk.DragIcon.get_for_drag(drag)"
      '';
  });
}
