defmodule Plsm.IO.Export do
  @doc """
    Generate the schema field based on the database type
  """
  def type_output({name, type, is_primary_key?}) do
    escaped_name = escaped_name(name)

    type_output_with_source(escaped_name, name, map_type(type), is_primary_key?)
    |> four_space()
  end

  defp map_type(:decimal), do: ":decimal"
  defp map_type(:float), do: ":float"
  defp map_type(:string), do: ":string"
  defp map_type(:text), do: ":string"
  defp map_type(:map), do: ":map"
  defp map_type(:date), do: ":naive_datetime"
  defp map_type(:integer), do: ":integer"
  defp map_type(:boolean), do: ":boolean"
  defp map_type(:none), do: ":none"
  defp map_type(:binary), do: ":binary"

  @doc """
  When escaped name and name are the same, source option is not needed
  """
  defp type_output_with_source(escaped_name, escaped_name, mapped_type, is_primary_key?),
    do: "field :#{escaped_name}, #{mapped_type}, primary_key: #{is_primary_key?}\n"

  @doc """
  When escaped name and name are different, add a source option poitning to the original field name as an atom
  """
  defp type_output_with_source(escaped_name, name, mapped_type, is_primary_key?),
    do:
      "field :#{escaped_name}, #{mapped_type}, primary_key: #{is_primary_key?}, source: :#{name}\n"

  @doc """
    Write the given schema to file.
  """
  @spec write(String.t(), String.t(), String.t()) :: Any
  def write(schema, name, path \\ "") do
    case File.open("#{path}#{name}.ex", [:write]) do
      {:ok, file} ->
        IO.puts("#{path}#{name}.ex")
        IO.binwrite(file, schema)
        File.close(file)

      {_, msg} ->
        IO.puts("Could not write #{name} to file: #{msg}")
    end
  end

  @doc """
  Format the text of a specific table with the fields that are passed in. This is strictly formatting and will not verify the fields with the database
  """
  @spec prepare(Plsm.Database.Table, String.t()) :: {Plsm.Database.TableHeader, String.t()}
  def prepare(table, project_name) do
    output =
      module_declaration(project_name, table.header.name) <>
        model_inclusion() <> schema_declaration(table.header.name)

    trimmed_columns = remove_foreign_keys(table.columns)
    foreign_columns_list = only_foreign_keys(table.columns)

    column_output =
      trimmed_columns
      |> Enum.reduce("", fn column, a ->
        case column.name do
          name when name != "id" -> # we don't want id
            if Enum.member?(foreign_columns_list, column.name) do # if a foreign key has the same name than a field add _s to the field
              a <> (type_output_with_source(column.name <> "_s", column.name, map_type(column.type), column.primary_key) |> four_space())
            else
              a <> type_output({column.name, column.type, column.primary_key})
            end
          _ ->
            ""
        end
      end)

    output = output <> column_output

    belongs_to_output =
      Enum.filter(table.columns, fn column ->
        column.foreign_table != nil and column.foreign_table != nil
      end)
      |> Enum.reduce("", fn column, a ->
        a <> belongs_to_output(project_name, column)
      end)

    output = output <> belongs_to_output <> "\n"

    output = output <> two_space(end_declaration())
    output = output <> changeset(table.columns) <> end_declaration()
    output <> end_declaration()
    {table.header, output}
  end

  defp module_declaration(project_name, table_name) do
    namespace = Plsm.Database.TableHeader.table_name(table_name)
    "defmodule #{project_name}.#{namespace} do\n"
  end

  defp model_inclusion do
    two_space("use Ecto.Schema\n" <> two_space("import Ecto.Changeset\n\n"))
  end

  defp schema_declaration(table_name) do
    two_space("schema \"#{table_name}\" do\n")
  end

  defp end_declaration do
    "end\n"
  end

  defp four_space(text) do
    "    " <> text
  end

  defp two_space(text) do
    "  " <> text
  end

  defp changeset(columns) do
    output = two_space("def changeset(struct, params \\\\ %{}) do\n")
    output = output <> four_space("struct\n")
    output = output <> four_space("|> cast(params, [" <> changeset_list(columns) <> "])\n")
    output <> two_space("end\n")
  end

  defp changeset_list(columns) do
    columns
    |> Enum.map(fn c -> ":#{escaped_name(c.name)}" end)
    |> Enum.join(", ")
  end

  @spec prepare(String.t(), Plsm.Database.Column) :: String.t()
  defp belongs_to_output(project_name, column) do
    column_name = column.name |> String.trim_trailing("_id")
    table_name = Plsm.Database.TableHeader.table_name(column.foreign_table)
    source = if column_name =~ "_uid", do: column_name, else: column_name <> "_id"
    "\n" <> four_space("belongs_to :#{column_name}, #{project_name}.#{table_name}, source: :#{source}")
  end

  defp only_foreign_keys(columns) do
    Enum.filter(columns, fn column ->
      column.foreign_table != nil and column.foreign_field != nil
    end)
    |> Enum.map(fn column -> column.name |> String.trim_trailing("_id") end)
  end

  defp remove_foreign_keys(columns) do
    Enum.filter(columns, fn column ->
      column.foreign_table == nil and column.foreign_field == nil
    end)
  end

  defp escaped_name(name) do
    name
    |> String.replace(" ", "_")
  end
end
