return function()
  local days = { "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado" }
  local months = { "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre" }

  local now = os.date("*t")

  local day_name = days[now.wday]
  local day_number = now.day
  local month_name = months[now.month]
  local year = now.year

  local formatted = string.format("%s %d de %s, %d", day_name, day_number, month_name, year)

  return {formatted}
end
