# Notes





## Fish/Tide Setup

```bash
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

fisher install IlanCosman/tide@v6

tide configure --auto --style=Rainbow --prompt_colors='True color' --show_time='24-hour format' --rainbow_prompt_separators=Angled --powerline_prompt_heads=Sharp --powerline_prompt_tails=Flat --powerline_prompt_style='Two lines, character' --prompt_connection=Solid --powerline_right_prompt_frame=No --prompt_connection_andor_frame_color=Darkest --prompt_spacing=Sparse --icons='Few icons' --transient=No
```
