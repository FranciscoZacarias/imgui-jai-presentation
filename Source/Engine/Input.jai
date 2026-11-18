Input :: #import "Input";

prev_button_states: [Input.NUM_BUTTON_STATES] Input.Key_Current_State;

input_store_previous_state :: () {
  memcpy(*prev_button_states, *Input.input_button_states, size_of(type_of(prev_button_states)));
}

is_key_up :: (key: Input.Key_Code) -> bool {
  return (Input.input_button_states[key] & .DOWN) == 0;
}

is_key_down :: (key: Input.Key_Code) -> bool {
  return (Input.input_button_states[key] & .DOWN) != 0;
}

is_key_clicked :: (key: Input.Key_Code) -> bool {
  return is_key_down(key) && was_key_up(key);
}

is_key_released :: (key: Input.Key_Code) -> bool {
  return is_key_up(key) && was_key_down(key);
}

was_key_down :: (key: Input.Key_Code) -> bool {
  return (prev_button_states[key] & .DOWN) != 0;
}

was_key_up :: (key: Input.Key_Code) -> bool {
  return (prev_button_states[key] & .DOWN) == 0;
}
