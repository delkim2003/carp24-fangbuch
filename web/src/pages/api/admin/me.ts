export const prerender = false;

export const GET = async ({ locals }: { locals: App.Locals }) => {
  const user = locals.user;
  if (!user) {
    return new Response(JSON.stringify({
      isAdmin: false,
      role: "GUEST",
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const role = locals.role ?? "USER";
  const isAdmin = locals.isAdmin ?? false;

  return new Response(JSON.stringify({ isAdmin, role }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};